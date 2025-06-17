const express = require('express');
const router = express.Router();
const Complaint = require('../models/Complaint');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { sendStatusUpdateEmail } = require('../services/emailService');

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadDir = path.join(__dirname, '../uploads');
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    const ext = path.extname(file.originalname);
    cb(null, 'complaint-' + uniqueSuffix + ext);
  }
});

const upload = multer({ 
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 }, 
  fileFilter: function (req, file, cb) {
    const filetypes = /jpeg|jpg|png/;
    const mimetype = filetypes.test(file.mimetype);
    const extname = filetypes.test(path.extname(file.originalname).toLowerCase());
    
    if (mimetype && extname) {
      return cb(null, true);
    }
    cb(new Error("Only .png, .jpg and .jpeg format allowed!"));
  }
});

router.get('/', async (req, res) => {
  try {
    const complaints = await Complaint.find().sort({ createdAt: -1 });
    res.json(complaints);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const complaint = await Complaint.findById(req.params.id);
    if (!complaint) return res.status(404).json({ message: 'Complaint not found' });
    res.json(complaint);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

router.post('/', upload.array('images', 5), async (req, res) => {
  try {
    const { category, businessName, description, contactEmail, district, neighborhood } = req.body;
    
    if (!category || !businessName || !description || !contactEmail) {
      return res.status(400).json({ 
        message: 'Missing required fields. Please provide category, businessName, description and contactEmail.' 
      });
    }
    
    const complaint = new Complaint({
      category,
      businessName,
      description,
      contactEmail,
      district,
      neighborhood
    });
    
    if (req.body['location[lat]'] && req.body['location[lng]']) {
      complaint.location = {
        lat: parseFloat(req.body['location[lat]']),
        lng: parseFloat(req.body['location[lng]'])
      };
    }
    
    if (req.files && req.files.length > 0) {
      const imageUrls = req.files.map(file => `/uploads/${file.filename}`);
      complaint.imageUrls = imageUrls;
    }
    
    const newComplaint = await complaint.save();
    res.status(201).json(newComplaint);
  } catch (err) {
    console.error('Error creating complaint:', err);
    res.status(400).json({ message: err.message });
  }
});

router.patch('/:id', async (req, res) => {
  try {
    const complaint = await Complaint.findById(req.params.id);
    if (!complaint) return res.status(404).json({ message: 'Complaint not found' });
    
    const previousStatus = complaint.status;
    
    const updateFields = [
      'description', 'contactEmail', 'status', 
      'category', 'businessName', 'district', 'neighborhood', 'adminMessage'
    ];
    
    updateFields.forEach(field => {
      if (req.body[field] !== undefined) {
        complaint[field] = req.body[field];
      }
    });
    
    if (req.body.location) {
      complaint.location = {
        lat: req.body.location.lat || complaint.location?.lat,
        lng: req.body.location.lng || complaint.location?.lng
      };
    }
    
    const updatedComplaint = await complaint.save();
    
    if (previousStatus !== updatedComplaint.status) {
      try {
        await sendStatusUpdateEmail(updatedComplaint);
      } catch (emailError) {
        console.error('E-posta gönderilirken hata oluştu:', emailError);
        
      }
    }
    
    res.json(updatedComplaint);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

router.use('/uploads', express.static(path.join(__dirname, '../uploads')));

module.exports = router; 