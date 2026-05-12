const mongoose = require("mongoose");

const VisitorSchema = new mongoose.Schema({
    name: String,
    time: String,
    confidence: Number
});

module.exports = mongoose.model("Visitor", VisitorSchema);
