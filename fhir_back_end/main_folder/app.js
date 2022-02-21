require("dotenv").config();
const MongoClient = require('mongodb').MongoClient;
var bcrypt = require('bcryptjs');
const jwt = require("jsonwebtoken");
require("./config/database").connect();
const express = require("express");
const JSONSchemaValidator = require('./fhir-json-schema-validator')
const Boom = require('boom');

const app = express();

const TOKEN_KEY = "tpuoonnjlwagecvwyist"

app.use(express.json());

const auth = require("./middleware/auth");
const User = require("./model/user");
const res = require("express/lib/response");



app.get("/welcome", auth, (req, res) => {
  res.status(200).send("Welcome 🙌 ");
});
// Register
app.post("/register", async (req, res) => {

  // Our register logic starts here
  try {
    // Get user input
    const { first_name, last_name, email, password } = req.body;

    // Validate user input
    if (!(email && password && first_name && last_name)) {
      res.status(400).send("All input is required");
    }

    // check if user already exist
    // Validate if user exist in our database
    const oldUser = await User.findOne({ email });

    if (oldUser) {
      return res.status(409).send("User Already Exist. Please Login");
    }

    //Encrypt user password
    encryptedPassword = await bcrypt.hash(password, 10);

    // Create user in our database
    const user = await User.create({
      first_name,
      last_name,
      email: email.toLowerCase(), // sanitize: convert email to lowercase
      password: encryptedPassword,
    });

    // Create token
    const token = jwt.sign(
      { user_id: user._id, email },
      TOKEN_KEY,
      {
        expiresIn: "2h",
      }
    );
    // save user token
    user.token = token;

    // return new user
    res.status(201).json(user);
  } catch (err) {
    console.log(err);
  }

});

// Login
app.post("/login", async (req, res) => {

  // Our login logic starts here
  try {
    // Get user input
    const { email, password } = req.body;

    // Validate user input
    if (!(email && password)) {
      res.status(400).send("All input is required");
    }
    // Validate if user exist in our database
    const user = await User.findOne({ email });

    if (user && (await bcrypt.compare(password, user.password))) {
      // Create token
      const token = jwt.sign(
        { user_id: user._id, email },
        TOKEN_KEY,
        {
          expiresIn: "2h",
        }
      );

      // save user token
      user.token = token;

      // user
      res.status(200).json(user);
    }
    res.status(400).send("Invalid Credentials");
  } catch (err) {
    console.log(err);
  }
});

app.get("/patientList", auth, async (req, res) => {
  let client = await MongoClient.connect('mongodb://localhost:27017');
  let patients = client.db('FHIR').collection('patients');

  // fetch all patients
  return await patients.find({},
    {
      projection: {
        _id: 0,
        id: 1,
        name: 1,
        gender: 1,
      }
    }
  ).toArray(function (err, result) {
    if (err) {
      res.send(err);
    } else {

      res.send(JSON.stringify(result));
    }
  });
});

app.get("/getPatient", auth, async (req,res) => {

  const { patientId } = req.body;
  console.log(patientId);
  let client = await MongoClient.connect('mongodb://localhost:27017');
  let patients = client.db('FHIR').collection('patients');

  let patient = await patients.findOne(
    {
      id: patientId
    },
    {
      projection : {
        _id: 0,
        id:1,	
        name: 1,
        gender : 1,
      }
    }
  );
  console.log(patient)
  return patient;
});

app.delete("/deletePatient", auth, async (req,res)=>{
  const { patientId } = req.body;
 
  const client = await MongoClient.connect('mongodb://localhost:27017');
  await client.db('FHIR').collection('patients').deleteOne({"id":patientId}, function(err, result) { 
    if (err) throw err;
    console.log("Document deleted")
    res.send({msg:"document deleted"})
});
 
  
});

app.post("/postPatient", auth, async (req,res)=>{
  try {
    const client = await MongoClient.connect('mongodb://localhost:27017');
    let patients = client.db('FHIR').collection('patients');

    const patientData = req.body
   

    const validator = new JSONSchemaValidator;
    let validationErrors = validator.validate(patientData)
    if (validationErrors.length > 0){
      console.log(validationErrors)
      console.log("Furhter error handling is needed!")
      const error = Boom.badRequest("The uploaded JSON does not fit the validation criterias");
      error.output.statusCode = 400;   
      error.output.payload["errors"] = validationErrors;
      return error;	
    }
    else{
      patients.insertOne(patientData)
      console.log("Patient added succsessfully")
      res.send({msg:"Patient added successfully"})
    }
    
    return patientData;
  } catch (e) {
    console.error(e.message);
    return Boom.internal(e);
  } finally {
    if (client && client.close){
      client.close();
    }
  }
});



module.exports = app;