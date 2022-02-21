import 'dart:html';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FHIR',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
      ),
      home: CatalogPage(),
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
      floatingActionButton: FloatingActionButton.extended(onPressed:  ()=>pickFile(context),
          label: const Text ('Upload document'), icon: const Icon(Icons.file_upload),backgroundColor: Colors.deepOrange,),
    );;
  }
}

Future<http.Response> pickFile(BuildContext context) async{
  FilePickerResult result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
  if (result != null){
    PlatformFile file=result.files.single;
    var data = file.bytes;
    var jsonString = utf8.decode(data);
    var jsonData= jsonString.replaceAll('#', '%23');
    print("test");
    http.Response response = await http.post(
      "http://localhost:3000/postPatient?data=$jsonData"
    );
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
    _fetchPatientList();
    searchController.addListener(_search);
  }


  void _fetchPatientList() async {
    http.Response response = await http.get('http://localhost:3000/patientList');
    print(response.body);
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
    _fetchPatientDetails(patientId);
    nameController.addListener(_handleTextChange);
  }

 
  void _fetchPatientDetails(patientId) async {
    http.Response response =
    await http.get('http://localhost:3000/getPatient?id=${patientId}');
    print(response.body.length);
    print(response.body);
    Map<String, dynamic> newPatientRaw = json.decode(response.body);
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
                        ElevatedButton(onPressed: ()=> deletePatient(context,patient.id), child: Text("Delete"))

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
void deletePatient(BuildContext context, String patientId)async {
  http.Response response = await http.get('http://localhost:3000/deletePatient/${patientId}');
  print(response.body.length);
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
