const Complaint = require('../models/Complaint');
const Business = require('../models/Business');
const stringSimilarity = require('string-similarity');

const standardizeTurkishText = (text) => {
  if (!text) return '';
  
  return text.toLowerCase()
    .replace(/ı/g, 'i')
    .replace(/ğ/g, 'g')
    .replace(/ü/g, 'u')
    .replace(/ş/g, 's')
    .replace(/ö/g, 'o')
    .replace(/ç/g, 'c')
    .replace(/â/g, 'a')
    .replace(/î/g, 'i')
    .replace(/û/g, 'u')
    
    .replace(/restaurant|restoran|restorant|lokanta|cafe|kafe|kafeterya/g, '')
    .replace(/market|süpermarket|supermarket|market/g, '')
    
    .replace(/[^a-z0-9]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
};

const createBusinessIdentifier = (name, district, neighborhood, location) => {
  
  let normalizedName = standardizeTurkishText(name);
  
  let identifier = normalizedName;
  
  if (district) {
    identifier += `_${standardizeTurkishText(district)}`;
  }
  
  if (neighborhood) {
    identifier += `_${standardizeTurkishText(neighborhood)}`;
  }
  
  if (location && location.lat && location.lng) {
    
    const roundedLat = Math.round(location.lat * 1000) / 1000;
    const roundedLng = Math.round(location.lng * 1000) / 1000;
    identifier += `_${roundedLat}_${roundedLng}`;
  }
  
  return identifier;
};

const findSimilarBusinesses = (businesses) => {
  const threshold = 0.85; 
  const similarGroups = {};
  const processedIds = new Set();
  
  const businessesByLocation = {};
  
  businesses.forEach(business => {
    
    const locationKey = `${business.district || ''}_${business.neighborhood || ''}`;
    if (!businessesByLocation[locationKey]) {
      businessesByLocation[locationKey] = [];
    }
    businessesByLocation[locationKey].push(business);
  });
  
  Object.values(businessesByLocation).forEach(locationBusinesses => {
    if (locationBusinesses.length <= 1) return;
    
    for (let i = 0; i < locationBusinesses.length; i++) {
      const business1 = locationBusinesses[i];
      if (processedIds.has(business1.businessId)) continue;
      
      const businessName1 = standardizeTurkishText(business1.businessName);
      const similarIds = [business1.businessId];
      
      for (let j = i + 1; j < locationBusinesses.length; j++) {
        const business2 = locationBusinesses[j];
        if (processedIds.has(business2.businessId)) continue;
        
        const businessName2 = standardizeTurkishText(business2.businessName);
        const similarity = stringSimilarity.compareTwoStrings(businessName1, businessName2);
        
        if (similarity >= threshold) {
          similarIds.push(business2.businessId);
          processedIds.add(business2.businessId);
        }
      }
      
      if (similarIds.length > 1) {
        const groupId = `group_${Object.keys(similarGroups).length + 1}`;
        similarGroups[groupId] = similarIds;
      }
      
      processedIds.add(business1.businessId);
    }
  });
  
  return similarGroups;
};

const mergeBusinesses = (businessAnalytics, similarGroups) => {
  
  Object.entries(similarGroups).forEach(([groupId, businessIds]) => {
    
    const primaryBusinessId = businessIds[0];
    const primaryBusiness = businessAnalytics[primaryBusinessId];
    
    if (!primaryBusiness) return;
    
    for (let i = 1; i < businessIds.length; i++) {
      const secondaryBusinessId = businessIds[i];
      const secondaryBusiness = businessAnalytics[secondaryBusinessId];
      
      if (!secondaryBusiness) continue;
      
      primaryBusiness.pendingComplaints += secondaryBusiness.pendingComplaints;
      primaryBusiness.inReviewComplaints += secondaryBusiness.inReviewComplaints;
      primaryBusiness.positiveComplaints += secondaryBusiness.positiveComplaints;
      primaryBusiness.negativeComplaints += secondaryBusiness.negativeComplaints;
      
      primaryBusiness.complaintIds = [
        ...primaryBusiness.complaintIds,
        ...secondaryBusiness.complaintIds
      ];
      
      primaryBusiness.notes = primaryBusiness.notes || [];
      primaryBusiness.notes.push(
        `${new Date().toISOString()} - Benzer işletme ile birleştirildi: ${secondaryBusiness.businessName}`
      );
      
      delete businessAnalytics[secondaryBusinessId];
    }
    
    primaryBusiness.merged = true;
    primaryBusiness.mergedCount = businessIds.length;
    primaryBusiness.originalName = primaryBusiness.businessName;
    
    const allNames = [primaryBusiness.businessName];
    businessIds.slice(1).forEach(id => {
      const business = businessAnalytics[id];
      if (business) allNames.push(business.businessName);
    });
    
    if (allNames.length > 1) {
      primaryBusiness.businessName = `${allNames[0]} (${allNames.slice(1).join(', ')})`;
    }
  });
  
  return businessAnalytics;
};

const updateBusinessScores = async (forceUpdate = false) => {
  try {
    
    const complaints = await Complaint.find().lean();
    
    const businessAnalytics = {};
    
    complaints.forEach(complaint => {
      
      if (!complaint.businessName) return;
      
      const businessName = complaint.businessName.trim();
      
      const businessId = createBusinessIdentifier(
        businessName,
        complaint.district,
        complaint.neighborhood,
        complaint.location
      );
      
      if (!businessAnalytics[businessId]) {
        businessAnalytics[businessId] = {
          businessId,
          businessName,
          pendingComplaints: 0,
          inReviewComplaints: 0,
          positiveComplaints: 0,
          negativeComplaints: 0,
          score: 0,
          location: null,
          district: null,
          neighborhood: null,
          complaintIds: [] 
        };
      }
      
      if (complaint._id) {
        businessAnalytics[businessId].complaintIds.push(complaint._id.toString());
      }
      
      switch (complaint.status) {
        case 'pending':
          businessAnalytics[businessId].pendingComplaints++;
          break;
        case 'in-review':
          businessAnalytics[businessId].inReviewComplaints++;
          break;
        case 'positive':
          businessAnalytics[businessId].positiveComplaints++;
          break;
        case 'negative':
          businessAnalytics[businessId].negativeComplaints++;
          break;
        default:
          break;
      }
      
      if (!businessAnalytics[businessId].location && complaint.location) {
        businessAnalytics[businessId].location = complaint.location;
      }
      
      if (!businessAnalytics[businessId].district && complaint.district) {
        businessAnalytics[businessId].district = complaint.district;
      }
      
      if (!businessAnalytics[businessId].neighborhood && complaint.neighborhood) {
        businessAnalytics[businessId].neighborhood = complaint.neighborhood;
      }
    });
    
    const similarGroups = findSimilarBusinesses(Object.values(businessAnalytics));
    const mergedBusinesses = mergeBusinesses(businessAnalytics, similarGroups);
    
    const updatePromises = [];
    
    for (const [businessId, businessData] of Object.entries(mergedBusinesses)) {
      
      const totalComplaints = 
        businessData.pendingComplaints + 
        businessData.inReviewComplaints + 
        businessData.positiveComplaints + 
        businessData.negativeComplaints;
        
      const score = 
        (businessData.pendingComplaints + businessData.inReviewComplaints) * 1.5 + 
        businessData.negativeComplaints * 1 + 
        totalComplaints * 0.5;
      
      businessData.score = Number(score.toFixed(1));
      
      businessData.isReadyForInspection = (
        businessData.inReviewComplaints > 0 && 
        businessData.pendingComplaints === 0
      );
      
      let businessAddress = '';
      if (businessData.neighborhood) {
        businessAddress += businessData.neighborhood;
      }
      if (businessData.district) {
        if (businessAddress) businessAddress += ', ';
        businessAddress += businessData.district;
      }
      businessData.businessAddress = businessAddress || 'Adres bilgisi yok';
      
      const existingBusiness = await Business.findOne({ businessId });
      
      if (existingBusiness) {
        
        const scoreChanged = existingBusiness.score !== businessData.score;
        
        if (forceUpdate || scoreChanged) {
          
          existingBusiness.pendingComplaints = businessData.pendingComplaints;
          existingBusiness.inReviewComplaints = businessData.inReviewComplaints;
          existingBusiness.positiveComplaints = businessData.positiveComplaints;
          existingBusiness.negativeComplaints = businessData.negativeComplaints;
          existingBusiness.complaintIds = businessData.complaintIds;
          existingBusiness.isReadyForInspection = businessData.isReadyForInspection;
          existingBusiness.lastUpdated = new Date();
          
          if (businessData.merged) {
            existingBusiness.merged = businessData.merged;
            existingBusiness.mergedCount = businessData.mergedCount;
            existingBusiness.originalName = businessData.originalName;
            existingBusiness.businessName = businessData.businessName;
          }
          
          if (scoreChanged) {
            existingBusiness.score = businessData.score;
          }
          
          updatePromises.push(existingBusiness.save());
        }
      } else {
        
        const newBusiness = new Business({
          businessId: businessData.businessId,
          businessName: businessData.businessName,
          district: businessData.district,
          neighborhood: businessData.neighborhood,
          location: businessData.location,
          pendingComplaints: businessData.pendingComplaints,
          inReviewComplaints: businessData.inReviewComplaints,
          positiveComplaints: businessData.positiveComplaints,
          negativeComplaints: businessData.negativeComplaints,
          score: businessData.score,
          isReadyForInspection: businessData.isReadyForInspection,
          complaintIds: businessData.complaintIds
        });
        
        if (businessData.merged) {
          newBusiness.merged = businessData.merged;
          newBusiness.mergedCount = businessData.mergedCount;
          newBusiness.originalName = businessData.originalName;
        }
        
        updatePromises.push(newBusiness.save());
      }
    }
    
    if (updatePromises.length > 0) {
      await Promise.all(updatePromises);
    }
    
    const businesses = await Business.find()
      .sort({ score: -1 });
    
    return businesses;
  } catch (error) {
    console.error('İşletme puanları güncellenirken hata oluştu:', error);
    throw error;
  }
};

const analyzeBusinesses = async () => {
  try {
    
    let businesses = await Business.find()
      .sort({ score: -1 });
    
    if (businesses.length === 0 || isDataStale(businesses)) {
      businesses = await updateBusinessScores();
    }
    
    return businesses;
  } catch (error) {
    console.error('İşletmeler analiz edilirken hata oluştu:', error);
    throw error;
  }
};

const isDataStale = (data) => {
  if (!data || data.length === 0) return true;
  
  const lastUpdated = data.reduce((latest, item) => {
    if (!latest || new Date(item.lastUpdated) > new Date(latest)) {
      return item.lastUpdated;
    }
    return latest;
  }, null);
  
  if (!lastUpdated) return true;
  
  const hoursSinceUpdate = (new Date() - new Date(lastUpdated)) / (1000 * 60 * 60);
  
  return hoursSinceUpdate > 6;
};

const getBusinessesByDistrict = async (district) => {
  try {
    
    await analyzeBusinesses();
    
    return Business.find({
      district: { $regex: new RegExp(district, 'i') }
    }).sort({ score: -1 });
  } catch (error) {
    console.error(`${district} ilçesindeki işletmeler alınırken hata oluştu:`, error);
    throw error;
  }
};

const getComplaintsByBusinessId = async (businessId) => {
  try {
    
    const business = await Business.findOne({ businessId });
    
    if (!business || !business.complaintIds || business.complaintIds.length === 0) {
      return [];
    }
    
    const complaints = await Complaint.find({
      _id: { $in: business.complaintIds }
    }).sort({ createdAt: -1 });
    
    return complaints;
  } catch (error) {
    console.error(`İşletmeye ait şikayetler alınırken hata oluştu:`, error);
    throw error;
  }
};

const forceUpdateScores = async () => {
  try {
    const startTime = Date.now();
    const results = await updateBusinessScores(true);
    const endTime = Date.now();
    
    return {
      success: true,
      message: `${results.length} işletme puanı başarıyla güncellendi.`,
      duration: `${((endTime - startTime) / 1000).toFixed(2)} saniye`
    };
  } catch (error) {
    console.error('Puanlar güncellenirken hata oluştu:', error);
    throw error;
  }
};

module.exports = {
  analyzeBusinesses,
  getBusinessesByDistrict,
  getComplaintsByBusinessId,
  forceUpdateScores
}; 