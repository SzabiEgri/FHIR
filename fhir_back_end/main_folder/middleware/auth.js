const jwt = require("jsonwebtoken");

const TOKEN_KEY="tpuoonnjlwagecvwyist"

const verifyToken = (req, res, next) => {
  const token =
    req.body.token || req.query.token || req.headers["x-access-token"];

  if (!token) {
    return res.status(403).send({"resposne":"A token is required for authentication",
                                    "test":"test"});
  }
  try {
    const decoded = jwt.verify(token, TOKEN_KEY);
    req.user = decoded;
  } catch (err) {
    return res.status(401).send("Invalid Token");
  }
  return next();
};

module.exports = verifyToken;