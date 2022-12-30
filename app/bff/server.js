//------------------------------------------------------------
// Add X-Ray SDK for Node.js with the middleware (Express)
// - https://docs.aws.amazon.com/xray/latest/devguide/xray-sdk-nodejs-middleware.html#xray-sdk-nodejs-middleware-express
//------------------------------------------------------------
const AWSXRay = require('aws-xray-sdk');
//------------------------------------------------------------

const express = require('express');

//------------------------------------------------------------
// Apply patches to Node.js libraries for tracing downstream HTTP requests
// - https://docs.aws.amazon.com/xray/latest/devguide/xray-sdk-nodejs-httpclients.html
// - https://github.com/aws-samples/aws-xray-sdk-node-sample/blob/master/index.js
//------------------------------------------------------------
// HTTP Client
AWSXRay.captureHTTPsGlobal(require('http'));
AWSXRay.capturePromise();
const axios = require('axios');

// // AWS SDK (not used in this sample)
// const AWS = AWSXRay.captureAWS(require('aws-sdk'));
//------------------------------------------------------------

const app = express();

//------------------------------------------------------------
// Open segment for X-Ray with the middleware (Express)
// - https://docs.aws.amazon.com/xray/latest/devguide/xray-sdk-nodejs-middleware.html#xray-sdk-nodejs-middleware-express
//------------------------------------------------------------
app.use(AWSXRay.express.openSegment('BFF'));
//------------------------------------------------------------

app.get('/api', (req, res) => {
  // Set variables
  const backend1Url = process.env.BACKEND_1_URL || '';
  const backend2Url = process.env.BACKEND_2_URL || '';

  // Call Backend #1
  axios.get(backend1Url).then(result1 => {

    // Call Backend #2
    axios.get(backend2Url).then(result2 => {
      res.json({
        'currentDate': result1.data.currentDate,
        'currentTime': result2.data.currentTime,
      });
    })
    .catch(err => {
      console.log(err);
    });

  })
  .catch(err => {
    console.log(err);
  });
});

app.get('/health', (req, res) => {
  res.json({
    'status': 'ok'
  });
});

//------------------------------------------------------------
// Close segment for X-Ray with the middleware (Express)
// - https://docs.aws.amazon.com/xray/latest/devguide/xray-sdk-nodejs-middleware.html#xray-sdk-nodejs-middleware-express
//------------------------------------------------------------
app.use(AWSXRay.express.closeSegment());
//------------------------------------------------------------

app.listen('80', () => {
  console.log(`Running on http://0.0.0.0:80`)
});