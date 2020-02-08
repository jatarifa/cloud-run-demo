const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

const dateUp = Date.now();

const opentracing = require('opentracing');
var ZipkinB3TextMapCodec = require('jaeger-client').ZipkinB3TextMapCodec;
var initTracer = require('jaeger-client').initTracer;
var PrometheusMetricsFactory = require('jaeger-client').PrometheusMetricsFactory;
var promClient = require('prom-client');

var config = {
  serviceName: 'app1',
};
var metrics = new PrometheusMetricsFactory(promClient, config.serviceName);
var options = {
  tags: {
    'app1.version': '1.0.0',
  },
  metrics: metrics,
};
var tracer = initTracer(config, options);

let codec = new ZipkinB3TextMapCodec({ urlEncoding: true });

tracer.registerInjector(opentracing.FORMAT_HTTP_HEADERS, codec);
tracer.registerExtractor(opentracing.FORMAT_HTTP_HEADERS, codec);

app.get('/', (req, res) => {
  const today = new Date();
  res.json({
    date: today,
    up: `${(Date.now() - dateUp)/1000}`,
    headers: req.headers,
  });
});

app.listen(port, () => {
  console.log(`Server running on port: ${port}`);
  console.log('Press CTRL + C to quit');
});
