const mongoose = require('mongoose');

const BusinessSchema = new mongoose.Schema({
  businessId: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  businessName: {
    type: String,
    required: true
  },
  district: String,
  neighborhood: String,
  location: {
    lat: Number,
    lng: Number
  },
  pendingComplaints: {
    type: Number,
    default: 0
  },
  inReviewComplaints: {
    type: Number,
    default: 0
  },
  positiveComplaints: {
    type: Number,
    default: 0
  },
  negativeComplaints: {
    type: Number,
    default: 0
  },
  score: {
    type: Number,
    default: 0
  },
  isReadyForInspection: {
    type: Boolean,
    default: false
  },
  lastUpdated: {
    type: Date,
    default: Date.now
  },
  complaintIds: [String]
});

module.exports = mongoose.model('Business', BusinessSchema); 