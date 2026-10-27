const test = require('node:test');
const assert = require('node:assert/strict');
const mqtt = require('mqtt');
const { getMqttConfig } = require('../../src/config/mqtt');
const { TOPICS } = require('../../src/mqtt/topics');

const enabled = process.env.FLESPI_MQTT_TEST === '1';

test('conecta por TLS a Flespi y recibe autorización para los topics de entrada', {
  skip: !enabled,
  timeout: 20_000,
}, async () => {
  const config = getMqttConfig(process.env);
  const broker = new URL(config.brokerUrl);
  assert.equal(broker.protocol, 'mqtts:', 'Flespi debe probarse por TLS');
  assert.equal(broker.hostname, 'mqtt.flespi.io', 'La prueba se limita al broker Flespi');
  assert.ok(process.env.MQTT_USERNAME, 'MQTT_USERNAME debe ser un token ACL de prueba');

  const client = mqtt.connect(config.brokerUrl, config.options);
  try {
    await new Promise((resolve, reject) => {
      client.once('connect', resolve);
      client.once('error', reject);
    });

    const grants = await new Promise((resolve, reject) => {
      client.subscribe(
        [TOPICS.TELEMETRY, TOPICS.STATUS, TOPICS.ACTUATOR_STATUS].map((topic) => ({ topic, qos: 1 })),
        (error, granted) => (error ? reject(error) : resolve(granted))
      );
    });

    assert.equal(grants.length, 3);
    assert.ok(grants.every((grant) => grant.qos > 0), 'El token debe poder suscribirse a los topics de entrada');

    await new Promise((resolve, reject) => {
      client.unsubscribe(
        [TOPICS.TELEMETRY, TOPICS.STATUS, TOPICS.ACTUATOR_STATUS],
        (error) => (error ? reject(error) : resolve())
      );
    });
  } finally {
    client.end(true);
  }
});
