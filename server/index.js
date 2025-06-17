const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const dotenv = require('dotenv');
const cron = require('node-cron');
const path = require('path');
const { forceUpdateScores } = require('./services/scoreService');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(express.json());

app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

mongoose.connect(process.env.MONGODB_URI)
  .then(() => {
    console.log('MongoDB bağlantısı başarılı');
    
    forceUpdateScores()
      .catch(err => console.error('Error updating business scores:', err));
  })
  .catch(err => console.error('MongoDB connection error:', err));

const complaintsRoutes = require('./routes/complaints');
const scoresRoutes = require('./routes/scores');

app.use('/api/complaints', complaintsRoutes);
app.use('/api/scores', scoresRoutes);

app.get('/api/health', (req, res) => {
  res.status(200).json({ status: 'OK', message: 'Server is running' });
});

cron.schedule('0 0 * * *', async () => {
  try {
    await forceUpdateScores();
  } catch (error) {
    console.error('Otomatik puan güncellemesi sırasında hata oluştu:', error);
  }
});

cron.schedule('0 * * * *', async () => {
  try {
    
    const Business = require('./models/Business');
    
    const oneHourAgo = new Date();
    oneHourAgo.setHours(oneHourAgo.getHours() - 1);
    
    const Complaint = require('./models/Complaint');
    const recentComplaints = await Complaint.find({
      $or: [
        { createdAt: { $gte: oneHourAgo } },
        { updatedAt: { $gte: oneHourAgo } }
      ]
    });
    
    if (recentComplaints.length > 0) {
      await forceUpdateScores();
    }
  } catch (error) {
    console.error('Saatlik puan kontrolü sırasında hata oluştu:', error);
  }
});

app.listen(PORT, () => {
  console.log(`Sunucu port ${PORT} üzerinde çalışıyor`);
}); 