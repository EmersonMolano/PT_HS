class UpdateDeviceRequest {
  constructor({ name, type, location, manufacturer = null, model = null, alertThreshold = null }) {
    this.name = name;
    this.type = type;
    this.location = location;
    this.manufacturer = manufacturer;
    this.model = model;
    this.alertThreshold = alertThreshold;
  }

  static fromRequest(body = {}) {
    return new UpdateDeviceRequest({
      name: body.name,
      type: body.type,
      location: body.location,
      manufacturer: body.manufacturer,
      model: body.model,
      alertThreshold: body.alertThreshold ?? body.umbralAlerta
    });
  }
}

module.exports = { UpdateDeviceRequest };
