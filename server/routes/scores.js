const express = require('express');
const router = express.Router();
const { analyzeBusinesses, getBusinessesByDistrict, getComplaintsByBusinessId, forceUpdateScores } = require('../services/scoreService');

router.get('/', async (req, res) => {
  try {
    const businesses = await analyzeBusinesses();
    res.json(businesses);
  } catch (err) {
    console.error('İşletmeler getirilemedi:', err);
    res.status(500).json({ message: err.message });
  }
});

router.get('/top/:limit', async (req, res) => {
  try {
    const limit = parseInt(req.params.limit) || 10;
    const allBusinesses = await analyzeBusinesses();
    const topBusinesses = allBusinesses.slice(0, limit);
    
    res.json(topBusinesses);
  } catch (err) {
    console.error('En yüksek puanlı işletmeler getirilemedi:', err);
    res.status(500).json({ message: err.message });
  }
});

router.get('/district/:district', async (req, res) => {
  try {
    const district = req.params.district;
    
    if (!district) {
      return res.status(400).json({ message: 'İlçe adı belirtilmelidir' });
    }
    
    const districtBusinesses = await getBusinessesByDistrict(district);
    res.json(districtBusinesses);
  } catch (err) {
    console.error('İlçedeki işletmeler getirilemedi:', err);
    res.status(500).json({ message: err.message });
  }
});

router.get('/score/:minScore', async (req, res) => {
  try {
    const minScore = parseFloat(req.params.minScore) || 3.0;
    const allBusinesses = await analyzeBusinesses();
    const highScoreBusinesses = allBusinesses.filter(
      business => business.score >= minScore
    );
    
    res.json(highScoreBusinesses);
  } catch (err) {
    console.error('Yüksek puanlı işletmeler getirilemedi:', err);
    res.status(500).json({ message: err.message });
  }
});

router.get('/business/:businessId/complaints', async (req, res) => {
  try {
    const businessId = req.params.businessId;
    
    if (!businessId) {
      return res.status(400).json({ message: 'İşletme ID belirtilmelidir' });
    }
    
    const complaints = await getComplaintsByBusinessId(businessId);
    res.json(complaints);
  } catch (err) {
    console.error('İşletmeye ait şikayetler getirilemedi:', err);
    res.status(500).json({ message: err.message });
  }
});

router.post('/update', async (req, res) => {
  try {
    const result = await forceUpdateScores();
    res.json(result);
  } catch (err) {
    console.error('Puanlar güncellenirken hata oluştu:', err);
    res.status(500).json({ message: err.message });
  }
});

router.get('/business/:businessId', async (req, res) => {
  try {
    const { businessId } = req.params;
    
    const Business = require('../models/Business');
    
    const business = await Business.findOne({ businessId });
    
    if (!business) {
      return res.status(404).json({ message: 'İşletme bulunamadı' });
    }
    
    res.json(business);
  } catch (err) {
    console.error('İşletme detayları alınırken hata oluştu:', err);
    res.status(500).json({ message: err.message });
  }
});

module.exports = router; 