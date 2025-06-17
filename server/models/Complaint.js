const mongoose = require('mongoose');

const ComplaintSchema = new mongoose.Schema({
  description: {
    type: String,
    required: true
  },
  contactEmail: {
    type: String,
    required: true
  },
  status: {
    type: String,
    default: 'pending',
    enum: ['pending', 'in-review', 'positive', 'negative', 'rejected']
  },
  category: {
    type: String,
    default: 'Diğer',
    required: true
  },
  businessName: {
    type: String,
    required: true
  },
  district: {
    type: String,
    default: null
  },
  neighborhood: {
    type: String,
    default: null
  },
  location: {
    lat: {
      type: Number
    },
    lng: {
      type: Number
    }
  },
  adminMessage: {
    type: String,
    default: null
  },
  imageUrls: {
    type: [String],
    default: []
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

ComplaintSchema.methods.parseData = function() {
  
  if (this.description) {
    const lines = this.description.split('\n');
    let actualDescriptionStart = 0;
    
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      
      if (line.startsWith('İşletme Adı:')) {
        this.businessName = line.replace('İşletme Adı:', '').trim();
      } else if (line.startsWith('İlçe:')) {
        this.district = line.replace('İlçe:', '').trim();
      } else if (line.startsWith('Mahalle:')) {
        this.neighborhood = line.replace('Mahalle:', '').trim();
      } else if (line.startsWith('Konum:')) {
        const locationStr = line.replace('Konum:', '').trim();
        if (locationStr.includes(',')) {
          const [lat, lng] = locationStr.split(',').map(coord => parseFloat(coord.trim()));
          if (!isNaN(lat) && !isNaN(lng)) {
            this.location = { lat, lng };
          }
        }
      }
      
      if (line === '' && i > 0) {
        actualDescriptionStart = i + 1;
        break;
      }
    }
    
    if (actualDescriptionStart > 0 && actualDescriptionStart < lines.length) {
      this.description = lines.slice(actualDescriptionStart).join('\n');
    }
  }
  
  return this;
};

ComplaintSchema.pre('save', function(next) {
  if (this.isNew) {
    this.parseData();
  }
  next();
});

module.exports = mongoose.model('Complaint', ComplaintSchema); 