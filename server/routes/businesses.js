const express = require('express');
const router = express.Router();
const Business = require('../models/Business');
const Complaint = require('../models/Complaint');
const { isAuthenticated } = require('../middleware/auth');
const { analyzeBusinesses, getBusinessesByDistrict, getComplaintsByBusinessId, forceUpdatePriorities } = require('../services/priorityService');

router.get('/', isAuthenticated, async (req, res) => {
  try {
    const businesses = await Business.find();
    res.json(businesses);
  } catch (error) {
    console.error('Error fetching businesses:', error);
    res.status(500).json({ message: 'Error fetching businesses' });
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
    const result = await forceUpdatePriorities();
    res.json(result);
  } catch (err) {
    console.error('Öncelik puanları güncellenirken hata oluştu:', err);
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

router.put('/:businessId/inspection', isAuthenticated, async (req, res) => {
  try {
    const { businessId } = req.params;
    const { isReadyForInspection } = req.body;

    const business = await Business.findOneAndUpdate(
      { businessId },
      { isReadyForInspection },
      { new: true }
    );

    if (!business) {
      return res.status(404).json({ message: 'Business not found' });
    }

    res.json(business);
  } catch (error) {
    console.error('Error updating business inspection status:', error);
    res.status(500).json({ message: 'Error updating business inspection status' });
  }
});

router.post('/merge', isAuthenticated, async (req, res) => {
  try {
    const { targetBusinessId, sourceBusinessIds } = req.body;

    const targetBusiness = await Business.findOne({ businessId: targetBusinessId });
    if (!targetBusiness) {
      return res.status(404).json({ message: 'Target business not found' });
    }

    const sourceBusinesses = await Business.find({ businessId: { $in: sourceBusinessIds } });
    if (sourceBusinesses.length !== sourceBusinessIds.length) {
      return res.status(404).json({ message: 'One or more source businesses not found' });
    }

    const allComplaintIds = new Set([
      ...targetBusiness.complaintIds,
      ...sourceBusinesses.flatMap(b => b.complaintIds)
    ]);

    targetBusiness.complaintIds = Array.from(allComplaintIds);
    targetBusiness.pendingComplaints = sourceBusinesses.reduce((sum, b) => sum + b.pendingComplaints, targetBusiness.pendingComplaints);
    targetBusiness.inReviewComplaints = sourceBusinesses.reduce((sum, b) => sum + b.inReviewComplaints, targetBusiness.inReviewComplaints);
    targetBusiness.positiveComplaints = sourceBusinesses.reduce((sum, b) => sum + b.positiveComplaints, targetBusiness.positiveComplaints);
    targetBusiness.negativeComplaints = sourceBusinesses.reduce((sum, b) => sum + b.negativeComplaints, targetBusiness.negativeComplaints);
    targetBusiness.merged = sourceBusinessIds;
    targetBusiness.mergedCount = sourceBusinessIds.length;
    targetBusiness.updatedAt = new Date();

    await targetBusiness.save();

    await Business.deleteMany({ businessId: { $in: sourceBusinessIds } });

    res.json(targetBusiness);
  } catch (error) {
    console.error('Error merging businesses:', error);
    res.status(500).json({ message: 'Error merging businesses' });
  }
});

module.exports = router; 