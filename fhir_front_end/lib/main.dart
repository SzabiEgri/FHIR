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
        title: Text( globals.dataType +' Catalog'),
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

void loadPage(BuildContext context, StatelessWidget page, String dataType){
  globals.dataType = dataType;
  Navigator.push(context, MaterialPageRoute(builder: (context) => page));
}

void loadStatefulPage(BuildContext context, StatefulWidget page){
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

  List<FHIR_Data> fhirDataList;


  List<FHIR_Data> displayedFhirDataList;

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

    List<Map<String, dynamic>> newFhirDataRaw =
    json.decode(response.body).cast<Map<String, dynamic>>();
    List<FHIR_Data> newFhirData =
    newFhirDataRaw.map((fhirData) => FHIR_Data.fromJson(fhirData)).toList();

    setState(() {
      fhirDataList = newFhirData;
      displayedFhirDataList = fhirDataList;
    });
  }

  /// Performs a case insensitive search.
  void _search() {
    if (searchController.text == '') {
      setState(() {
        displayedFhirDataList = fhirDataList;
      });
    } else {
      List<FHIR_Data> filteredFhirData = fhirDataList
          .where((fhirData) => fhirData.data["id"]
          .toLowerCase()
          .contains(searchController.text.toLowerCase()))
          .toList();
      setState(() {
        displayedFhirDataList = filteredFhirData;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return displayedFhirDataList != null
        ? Column(
      children: <Widget>[
        new Container(padding:const EdgeInsets.all(8.0) ,
            child: DropdownButton(
          value: globals.dataType,
          items: globals.availableDataTypes.map((item){
            return new DropdownMenuItem<String>(value:item,
                child: new Text(item, style: TextStyle(fontFamily: "Gotham")));
          }).toList(),
          onChanged: (String newValue) {
            loadPage(context, CatalogPage(), newValue);
          },
        )),
        new Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: TextField(
            decoration: InputDecoration(hintText: 'Search by ID...'),
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
                      displayedFhirDataList[index].data["id"],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (BuildContext context) {
                            return DetailPage(displayedFhirDataList[index].data["id"]);
                          }));
                    }),
              ),
              itemCount: displayedFhirDataList.length,
            ),
          ),
        ),
      ],
    )
        : Center(child: CircularProgressIndicator());
  }
}

class FHIR_Data {
  final Map data;
  FHIR_Data.fromJson(Map<String, dynamic> json)
      : data = json;

}

class DetailPage extends StatefulWidget {
  final String fhirDataId;

  DetailPage(this.fhirDataId);

  @override
  _DetailPageState createState() => _DetailPageState(this.fhirDataId);
}

String getPrettyJSONString(jsonObject){
  var encoder = new JsonEncoder.withIndent("     ");
  return encoder.convert(jsonObject);
}

class _DetailPageState extends State<DetailPage>{
  FHIR_Data fhirData;
  var title;
  /// Flag indicating whether the name field is nonempty.
  bool fieldHasContent = false;

 // final TextEditingController jsonTextController = TextEditingController();
  /// The controller to keep track of name field content and changes.
  final TextEditingController jsonStringController = TextEditingController();

  /// Kicks off API fetch on creation.
  _DetailPageState(String fhirDataId) {
    title=fhirDataId;
    _fetchDataDetails(fhirDataId, globals.dataType);
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
    var newFHIRDataRaw = jsonResponse["data"];
    print(newFHIRDataRaw);

    FHIR_Data newFHIRData = FHIR_Data.fromJson(newFHIRDataRaw);
    setState(() {
      fhirData = newFHIRData;
      jsonStringController.text=getPrettyJSONString(newFHIRDataRaw);
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? ''),
      ),
      body: fhirData != null
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
                      children:[
                        Container(
                          child:TextFormField(
                            controller: jsonStringController,
                            keyboardType: TextInputType.multiline,
                            maxLines: null,
                          ),
                          height: 700,

                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center, //Center Row contents horizontally,
                          children: [

                          Container(child: ElevatedButton(onPressed: ()=> deleteData(context,title,globals.dataType ),
                              child: Text("Delete")),margin:  EdgeInsets.all(10)),
                          Container(child: ElevatedButton(onPressed: ()=> updateData(context,title,globals.dataType,jsonStringController),
                              child: Text("Edit")),margin:  EdgeInsets.all(10))

                        ],)


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

void updateData(BuildContext context, String dataId, String dataType, TextEditingController jsonTextController) async{
  final uri = Uri.http('localhost:4001','/updateData');
  var jsonString = jsonTextController.text;
  http.Response response = await http.post(
     uri,
      headers: {"Content-Type": "application/json",'x-access-token':globals.jwt},
      body: jsonString);
  print(response.statusCode);
  print(response.body);

  if (response.statusCode == 200){
    showDialog(context: context,
        builder: (_) => AlertDialog(
            title: Text("Success"),
            content: Text("JSON file updated successfully"),
            actions: [
              FlatButton(onPressed: ()=>{
                refreshPage(context,CatalogPage())
              }, child: Text("Accept"))
            ]
        ));
  }
  else{
    showDialog(context: context,
        builder: (_) => AlertDialog(
            title: Text("Failed"),
            content: Text("Could not update data file"),
            actions: [
              FlatButton(onPressed: ()=>{
                refreshPage(context,CatalogPage())
              }, child: Text("Accept"))
            ]
        ));
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
  Widget _buildSignupBtn() {
    return GestureDetector(
      onTap: () => loadStatefulPage(context, SignupScreen()),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Don\'t have an Account? ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.0,
                fontWeight: FontWeight.w400,
              ),
            ),
            TextSpan(
              text: 'Sign Up',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
      loadPage(context, CatalogPage(),"Patient");
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
                      _buildLoginBtn(),
                      _buildSignupBtn()
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

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {

  final emailTextEditorController = TextEditingController();
  final passwordTextEditorController = TextEditingController();
  final firstNameTextEditorController = TextEditingController();
  final lastNameTextEditorController = TextEditingController();



  Future<http.Response> signup(BuildContext context) async{
    String email = emailTextEditorController.text.toString();
    String password = passwordTextEditorController.text.toString();
    String firstName = firstNameTextEditorController.text.toString();
    String lastName = lastNameTextEditorController.text.toString();
    Map data = {
      "email" : email,
      "password" : password,
      "first_name":firstName,
      "last_name":lastName,
    };
    var body = json.encode(data);
    http.Response response = await http.post(
        "http://localhost:4001/register",
        headers: {"Content-Type": "application/json"},
        body:body
    );

    print(response.statusCode);
    if (response.statusCode == 200){
      loadStatefulPage(context, LoginScreen());
      var jsonResponse = jsonDecode(response.body);
      var token = jsonResponse["user"]["token"];
      print(jsonResponse);
      globals.availableDataTypes=jsonResponse["dataTypes"];
      print(token);
      print(globals.availableDataTypes);
      globals.jwt=token;

    }
    else{
      print("Sign up failed, handling required");
      emailTextEditorController.clear();
      passwordTextEditorController.clear();
      showDialog(context: context,
          builder: (_) => AlertDialog(
              title: Text("Error"),
              content: Text("The user already exists"),
              actions: [
                FlatButton(onPressed: ()=>{
                  Navigator.pop(context)
                }, child: Text("Accept"))
              ]
          ));
    }


  }

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
  Widget _buildFirstNameTF() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'First Name',
          style: kLabelStyle,
        ),
        SizedBox(height: 10.0),
        Container(
          alignment: Alignment.centerLeft,
          decoration: kBoxDecorationStyle,
          height: 60.0,
          child: TextField(
            controller: firstNameTextEditorController,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'OpenSans',
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(top: 14.0),
              hintText: 'Enter your first name',
              hintStyle: kHintTextStyle,
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildLastNameTF() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Last Name',
          style: kLabelStyle,
        ),
        SizedBox(height: 10.0),
        Container(
          alignment: Alignment.centerLeft,
          decoration: kBoxDecorationStyle,
          height: 60.0,
          child: TextField(
            controller: lastNameTextEditorController,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'OpenSans',
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(top: 14.0),
              hintText: 'Enter your last name',
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

  Widget _buildLoginBtn() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 25.0),
      width: double.infinity,
      child: RaisedButton(
        elevation: 5.0,
        onPressed: () => signup(context),
        padding: EdgeInsets.all(15.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
        color: Colors.white,
        child: Text(
          'SIGN UP',
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
                        'Sign Up',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'OpenSans',
                          fontSize: 30.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 30.0),
                      _buildEmailTF(),
                      SizedBox(height: 30.0),
                      _buildFirstNameTF(),
                      SizedBox(height: 30.0),
                      _buildLastNameTF(),
                      SizedBox(
                        height: 30.0,
                      ),
                      _buildPasswordTF(),
                      _buildLoginBtn(),

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







