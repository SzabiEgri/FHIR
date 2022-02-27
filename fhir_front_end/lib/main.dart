import 'dart:html';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'globals.dart' as globals;
import 'package:http/http.dart' as http;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FHIR',
      theme: ThemeData(
        primarySwatch: MaterialColor(0xFF398AE5,color),
      ),
      home: LoginScreen(),
    );
  }
}


class CatalogPage extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Catalog'),
      ),
      body: Center(
        child: CatalogList(),

      ),
      floatingActionButton: FloatingActionButton.extended(onPressed:  ()=>pickFile(context,globals.dataType),
          label: const Text ('Upload document'), icon: const Icon(Icons.file_upload),backgroundColor: Color(0xFF398AE5)),
    );;
  }
}

Future<http.Response> pickFile(BuildContext context, String dataType) async{
  FilePickerResult result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
  if (result != null){
    PlatformFile file=result.files.single;
    var data =  file.bytes;
    var jsonString = utf8.decode(data);
    print(jsonString);
    http.Response response = await http.post(
        "http://localhost:4001/postData",
        headers: {"Content-Type": "application/json",'x-access-token':globals.jwt},
        body:jsonString
    );
    print(response.statusCode);
    print(response.body);

    if (response.statusCode == 200){
      showDialog(context: context,
          builder: (_) => AlertDialog(
              title: Text("Success"),
              content: Text("JSON file added to database successfully"),
              actions: [
                FlatButton(onPressed: ()=>{
                  refreshPage(context,CatalogPage())
                }, child: Text("Accept"))
              ]
          ));
    }
    else{
      final Map responseBody = json.decode(response.body);
      var errors = responseBody["errors"];
      print(errors);
      showDialog(context: context,
          builder: (_) => AlertDialog(
              title: Text("Failed"),
              content: Text(responseBody["message"]),
              actions: [
                FlatButton(onPressed: ()=>{
                  refreshPage(context,CatalogPage())
                }, child: Text("Accept"))
              ]
          ));
    }

  }
  else{
    showDialog(context: context,
        builder: (_) => AlertDialog(
            title: Text("Failed"),
            content: Text("Failed to load file"),
            actions: [
              FlatButton(onPressed: ()=>{
                refreshPage(context,CatalogPage())
              }, child: Text("Accept"))
            ]
        ));
  }
}

void loadPage(BuildContext context, StatelessWidget page){
  Navigator.push(context, MaterialPageRoute(builder: (context) => page));
}

void refreshPage(BuildContext context, StatelessWidget page){
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (context) => page),
        (Route<dynamic> route) => false,
  );
}

class CatalogList extends StatefulWidget {
  @override
  _CatalogListState createState() => _CatalogListState();
}

class _CatalogListState extends State<CatalogList> {

  List<Patient> patients;


  List<Patient> displayedPatients;

  /// The controller to keep track of search field content and changes.
  final TextEditingController searchController = TextEditingController();

  /// Kicks off API fetch on creation.
  _CatalogListState() {
    _fetchDataList(globals.dataType);
    searchController.addListener(_search);
  }


  void _fetchDataList(String dataType) async {
    final queryParameters ={
      "dataType":dataType,
    };
    final uri = Uri.http('localhost:4001','/getDataList', queryParameters);
    final headers = {HttpHeaders.contentTypeHeader: 'application/json','x-access-token':globals.jwt};
    http.Response response = await http.get(uri,headers: headers);

    List<Map<String, dynamic>> newPatientsRaw =
    json.decode(response.body).cast<Map<String, dynamic>>();
    List<Patient> newPatients =
    newPatientsRaw.map((patientData) => Patient.fromJson(patientData)).toList();
    for(var patient in newPatients){
      patient.processName();
    }
    setState(() {
      patients = newPatients;
      displayedPatients = patients;
    });
  }

  /// Performs a case insensitive search.
  void _search() {
    if (searchController.text == '') {
      setState(() {
        displayedPatients = patients;
      });
    } else {
      List<Patient> filteredPatients = patients
          .where((patient) => patient.name
          .toLowerCase()
          .contains(searchController.text.toLowerCase()))
          .toList();
      setState(() {
        displayedPatients = filteredPatients;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return displayedPatients != null
        ? Column(
      children: <Widget>[
        new Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: TextField(
            decoration: InputDecoration(hintText: 'Search for patients...'),
            controller: searchController,
          ),
        ),
        new Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListView.builder(
              itemBuilder: (BuildContext context, int index) => Card(
                elevation: 2.0,
                child: ListTile(
                    title: Text(
                      displayedPatients[index].name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                        displayedPatients[index].gender),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (BuildContext context) {
                            return DetailPage(displayedPatients[index].id);
                          }));
                    }),
              ),
              itemCount: displayedPatients.length,
            ),
          ),
        ),
      ],
    )
        : Center(child: CircularProgressIndicator());
  }
}

class Patient {
  final String id;
  String name;
  final String gender;
  String familyName;
  List<dynamic> givenNamesRaw;
  String givenNames='';
  var rawName;

  
  Patient.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        gender = json['gender'],
        rawName = json['name'];

  processName(){
    familyName = rawName[0]["family"];
    givenNamesRaw = rawName[0]["given"];
    name = '';
    for (var givenName in givenNamesRaw){
        name = name+givenName.toString()+" ";
        givenNames = givenNames + givenName.toString() + " ";
    }
    name = name + familyName;
  }

}

class DetailPage extends StatefulWidget {
  final String patientId;

  DetailPage(this.patientId);

  @override
  _DetailPageState createState() => _DetailPageState(this.patientId);
}

class _DetailPageState extends State<DetailPage>{
  Patient patient;
  /// Flag indicating whether the name field is nonempty.
  bool fieldHasContent = false;

  /// The controller to keep track of name field content and changes.
  final TextEditingController nameController = TextEditingController();

  /// Kicks off API fetch on creation.
  _DetailPageState(String patientId) {
    _fetchDataDetails(patientId, globals.dataType);
    nameController.addListener(_handleTextChange);
  }

 
  void _fetchDataDetails(dataId, dataType) async {

    final queryParameters ={
      "dataId":dataId,
      "dataType":dataType,
    };
    final uri = Uri.http('localhost:4001','/getData', queryParameters);
    final headers = {HttpHeaders.contentTypeHeader: 'application/json','x-access-token':globals.jwt};
    http.Response response = await http.get(uri,headers: headers);

    var jsonResponse = jsonDecode(response.body);
    var newPatientRaw = jsonResponse["data"];


    Patient newPatient = Patient.fromJson(newPatientRaw);
    newPatient.processName();
    setState(() {
      patient = newPatient;
    });
  }


  void _handleTextChange() {
    setState(() {
      fieldHasContent = nameController.text != '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(patient?.name ?? ''),
      ),
      body: patient != null
          ? new Center(
        child: new SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Card(
              elevation: 5.0,
              child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        _BodySection('Gender', patient.gender),
                        _BodySection('Family name', patient.familyName),
                        _BodySection('Given names', patient.givenNames),
                        ElevatedButton(onPressed: ()=> deleteData(context,patient.id,globals.dataType ), child: Text("Delete"))

                      ],
                    ),
                  )),
            ),
          ),
        ),
      )
          : Center(child: CircularProgressIndicator()),
    );
  }
}
void deleteData(BuildContext context, String dataId, String dataType)async {
  final queryParameters ={
    "dataType":dataType,
    "dataId":dataId
  };
  final uri = Uri.http('localhost:4001','/deleteData', queryParameters);
  final headers = {HttpHeaders.contentTypeHeader: 'application/json','x-access-token':globals.jwt};
  final http.Response response = await http.delete(uri,headers: headers);
  print(response.body);
  if (response.statusCode == 200){
    showDialog(context: context,
        builder: (_) => AlertDialog(
            title: Text("Success"),
            content: Text("File deleted from the database successfully"),
            actions: [
              FlatButton(onPressed: ()=>{
                refreshPage(context,CatalogPage())
              }, child: Text("Accept"))
            ]
        ));
  }
  else{
    final Map responseBody = json.decode(response.body);
    var errors = responseBody["errors"];
    print(errors);
    showDialog(context: context,
        builder: (_) => AlertDialog(
            title: Text("Failed"),
            content: Text(responseBody["message"]),
            actions: [
              FlatButton(onPressed: ()=>{
                refreshPage(context,CatalogPage())
              }, child: Text("Accept"))
            ]
        ));
  }
}


class _BodySection extends StatelessWidget {
  final String title;
  final String content;

  _BodySection(this.title, this.content);

  @override
  Widget build(BuildContext context) {
    return new Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.title),
          Text(content, style: TextStyle(color: Colors.grey[700]))
        ],
      ),
    );
  }
}

Map<int, Color> color =
{
  50:Color.fromRGBO(57, 138, 229, .1),
  100:Color.fromRGBO(57, 138, 229, .2),
  200:Color.fromRGBO(57, 138, 229, .3),
  300:Color.fromRGBO(57, 138, 229, .4),
  400:Color.fromRGBO(57, 138, 229, .5),
  500:Color.fromRGBO(57, 138, 229, .6),
  600:Color.fromRGBO(57, 138, 229, .7),
  700:Color.fromRGBO(57, 138, 229, .8),
  800:Color.fromRGBO(57, 138, 229, .9),
  900:Color.fromRGBO(57, 138, 229, 1),
};

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final emailTextEditorController = TextEditingController();
  final passwordTextEditorController = TextEditingController();

  Widget _buildEmailTF() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Email',
          style: kLabelStyle,
        ),
        SizedBox(height: 10.0),
        Container(
          alignment: Alignment.centerLeft,
          decoration: kBoxDecorationStyle,
          height: 60.0,
          child: TextField(
            controller: emailTextEditorController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'OpenSans',
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(top: 14.0),
              prefixIcon: Icon(
                Icons.email,
                color: Colors.white,
              ),
              hintText: 'Enter your Email',
              hintStyle: kHintTextStyle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordTF() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Password',
          style: kLabelStyle,
        ),
        SizedBox(height: 10.0),
        Container(
          alignment: Alignment.centerLeft,
          decoration: kBoxDecorationStyle,
          height: 60.0,
          child: TextField(
            controller: passwordTextEditorController,
            obscureText: true,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'OpenSans',
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(top: 14.0),
              prefixIcon: Icon(
                Icons.lock,
                color: Colors.white,
              ),
              hintText: 'Enter your Password',
              hintStyle: kHintTextStyle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForgotPasswordBtn() {
    return Container(
      alignment: Alignment.centerRight,
      child: FlatButton(
        onPressed: () => print('Forgot Password Button Pressed'),
        padding: EdgeInsets.only(right: 0.0),
        child: Text(
          'Forgot Password?',
          style: kLabelStyle,
        ),
      ),
    );
  }
  Widget _buildLoginBtn() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 25.0),
      width: double.infinity,
      child: RaisedButton(
        elevation: 5.0,
        onPressed: () => login(context),
        padding: EdgeInsets.all(15.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
        color: Colors.white,
        child: Text(
          'LOGIN',
          style: TextStyle(
            color: Color(0xFF527DAA),
            letterSpacing: 1.5,
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
            fontFamily: 'OpenSans',
          ),
        ),
      ),
    );
  }

  Future<http.Response> login(BuildContext context) async{
    String email = emailTextEditorController.text.toString();
    String password = passwordTextEditorController.text.toString();
    Map data = {
      "email" : email,
      "password" : password
    };
    var body = json.encode(data);
    http.Response response = await http.post(
        "http://localhost:4001/login",
        headers: {"Content-Type": "application/json"},
        body:body
    );

    print(response.statusCode);
    if (response.statusCode == 200){
      loadPage(context, CatalogPage());
      var jsonResponse = jsonDecode(response.body);
      var token = jsonResponse["user"]["token"];
      print(jsonResponse);
      globals.availableDataTypes=jsonResponse["dataTypes"];
      print(token);
      print(globals.availableDataTypes);
      globals.jwt=token;

    }
    else{
      print("Loin failed, handling required");
      emailTextEditorController.clear();
      passwordTextEditorController.clear();
      showDialog(context: context,
          builder: (_) => AlertDialog(
              title: Text("Incorrect credentials"),
              content: Text("The email password combination doesn't exist"),
              actions: [
                FlatButton(onPressed: ()=>{
                  Navigator.pop(context)
                }, child: Text("Accept"))
              ]
          ));
    }


  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: <Widget>[
              Container(
                height: double.infinity,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF73AEF5),
                      Color(0xFF61A4F1),
                      Color(0xFF478DE0),
                      Color(0xFF398AE5),
                    ],
                    stops: [0.1, 0.4, 0.7, 0.9],
                  ),
                ),
              ),
              Container(
                height: double.infinity,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: 40.0,
                    vertical: 120.0,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        'Sign In',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'OpenSans',
                          fontSize: 30.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 30.0),
                      _buildEmailTF(),
                      SizedBox(
                        height: 30.0,
                      ),
                      _buildPasswordTF(),
                      _buildForgotPasswordBtn(),
                      _buildLoginBtn()
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

final kHintTextStyle = TextStyle(
  color: Colors.white54,
  fontFamily: 'OpenSans',
);

final kLabelStyle = TextStyle(
  color: Colors.white,
  fontWeight: FontWeight.bold,
  fontFamily: 'OpenSans',
);

final kBoxDecorationStyle = BoxDecoration(
  color: Color(0xFF6CA8F1),
  borderRadius: BorderRadius.circular(10.0),
  boxShadow: [
    BoxShadow(
      color: Colors.black12,
      blurRadius: 6.0,
      offset: Offset(0, 2),
    ),
  ],
);







