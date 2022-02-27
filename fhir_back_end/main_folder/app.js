require("dotenv").config();
const MongoClient = require('mongodb').MongoClient;
var bcrypt = require('bcryptjs');
const jwt = require("jsonwebtoken");
require("./config/database").connect();
const express = require("express");
const JSONSchemaValidator = require('./fhir-json-schema-validator')
const Boom = require('boom');
const cors = require('cors')

const app = express();
app.use(cors())

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
    console.log(email)
    console.log(password)
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

      var dataTypes = []
      //fetch the names of all available collections
      let client = await MongoClient.connect('mongodb://localhost:27017');
      await client.db('FHIR').listCollections().toArray(function(err, collInfos) {
        console.log(collInfos.length)
        collInfos.forEach(coll => {
          if(coll.name !== "users"){
            dataTypes.push(coll.name)
          }
         
        });
        res.status(200).json({"dataTypes":dataTypes,"user":user});
      });
      console.log("Hey")
      console.log(dataTypes)
      console.log("Ho")
      // user
     
    }
    else{
      res.status(400).send("Invalid Credentials");
    }
    
  } catch (err) {
    console.log(err);
  }
});

app.get("/getDataList", auth, async (req, res) => {
  const {dataType} = req.query
  let client = await MongoClient.connect('mongodb://localhost:27017');
  let collection = client.db('FHIR').collection(dataType);
 
 

  // fetch all data
  return await collection.find({}).toArray(function (err, result) {
    if (err) {
      res.send(err);
    } else {

      res.send(JSON.stringify(result));
    }
  });
});

app.get("/getData", auth, async (req,res) => {
  const { dataId, dataType } = req.query;
  let client = await MongoClient.connect('mongodb://localhost:27017');
  let collection = client.db('FHIR').collection(dataType);

  await collection.findOne({"id":dataId}, function(err, result) { 
    if (err) throw err;
    res.send({msg:"document found", data:result})
});
});

app.delete("/deleteData", auth, async (req,res)=>{
  const { dataId, dataType } = req.query;
  console.log(dataId)
  const client = await MongoClient.connect('mongodb://localhost:27017');
  await client.db('FHIR').collection(dataType).deleteOne({"id":dataId}, function(err, result) { 
    if (err) throw err;
    console.log("Document deleted")
    res.send({msg:"document deleted", dataId:dataId, dataType:dataType})
});
 
  
});

app.post("/postData", auth, async (req,res)=>{
  try {
    const dataToPost = req.body;
    console.log(dataToPost)
    const client = await MongoClient.connect('mongodb://localhost:27017');
    dataType=dataToPost["resourceType"]
    console.log(dataType)
    let collection = client.db('FHIR').collection(dataType);
    
    const validator = new JSONSchemaValidator;
    let validationErrors = validator.validate(dataToPost)
    if (validationErrors.length > 0){
      console.log(validationErrors)
      console.log("Furhter error handling is needed!")
      const error = Boom.badRequest("The uploaded JSON does not fit the validation criterias");
      error.output.statusCode = 400;   
      error.output.payload["errors"] = validationErrors;
      res.send(error);	
    }
    else{
      collection.insertOne(dataToPost)
      console.log("Document added succsessfully")
      res.send({msg:"Document added successfully"})
    }
    
    return dataToPost;
  } catch (e) {
    console.error(e.message);
    return Boom.internal(e);
  }
});



module.exports = app;