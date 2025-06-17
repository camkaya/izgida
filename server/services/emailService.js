const nodemailer = require('nodemailer');
const path = require('path');
const fs = require('fs');

const transporter = nodemailer.createTransport({
  service: 'gmail',  
  auth: {
    user: process.env.EMAIL_USER,  
    pass: process.env.EMAIL_PASS   
  }
});

const sendStatusUpdateEmail = async (complaint) => {
  try {
    
    if (!process.env.EMAIL_USER || !process.env.EMAIL_PASS) {
      console.error('E-posta gönderilemedi: EMAIL_USER ve EMAIL_PASS çevre değişkenleri tanımlanmamış.');
      return false;
    }
    
    if (!complaint.contactEmail) {
      console.warn('E-posta gönderilemedi: Alıcı e-postası belirtilmemiş.');
      return false;
    }
    
    let statusText = '';
    let subject = '';
    
    switch (complaint.status) {
      case 'in-review':
        statusText = 'işleme alınmıştır';
        subject = 'Şikayetiniz İşleme Alındı';
        break;
      case 'positive':
        statusText = 'olumlu değerlendirilmiştir';
        subject = 'Şikayetiniz Değerlendirildi: Olumlu Sonuç';
        break;
      case 'negative':
        statusText = 'olumsuz değerlendirilmiştir';
        subject = 'Şikayetiniz Değerlendirildi: Olumsuz Sonuç';
        break;
      default:
        statusText = 'güncellenmiştir';
        subject = 'Şikayet Durumu Güncellendi';
    }
    
    const logoPath = path.join(__dirname, '../../client/assets/images/logo.png');
    const logoExists = fs.existsSync(logoPath);
    
    const mailOptions = {
      from: `İzGıda <${process.env.EMAIL_USER}>`,
      to: complaint.contactEmail,
      subject: subject,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 5px;">
          ${logoExists ? `<div style="text-align: center; margin-bottom: 20px;">
            <img src="cid:logo" alt="İzGıda Logo" style="max-width: 150px; height: auto;" />
          </div>` : ''}
          <h2 style="color: #4CAF50; text-align: center;">Gıda Şikayeti Durum Güncellemesi</h2>
          <p>"<strong>${complaint.businessName}</strong>" işletmesi hakkındaki şikayetiniz <strong>${statusText}</strong>.</p>
          
          ${complaint.adminMessage 
            ? `<div style="background-color: #f9f9f9; padding: 15px; border-left: 4px solid #4CAF50; margin: 15px 0;">
                <p style="margin: 0; font-style: italic;">${complaint.adminMessage}</p>
              </div>`
            : ''
          }
          
          <p>Şikayet detayları:</p>
          <ul>
            <li><strong>İşletme:</strong> ${complaint.businessName}</li>
            <li><strong>Kategori:</strong> ${complaint.category}</li>
            <li><strong>İçerik:</strong> ${complaint.description.substring(0, 100)}${complaint.description.length > 100 ? '...' : ''}</li>
          </ul>
          
          <p>İzGıda uygulamasını kullandığınız için teşekkür ederiz.</p>
          <p style="text-align: center; margin-top: 20px; font-size: 12px; color: #666;">
            Bu e-posta otomatik olarak gönderilmiştir, lütfen cevaplamayınız.
          </p>
        </div>
      `,
      attachments: logoExists ? [
        {
          filename: 'logo.png',
          path: logoPath,
          cid: 'logo'
        }
      ] : []
    };
    
    console.log(`E-posta gönderiliyor: ${process.env.EMAIL_USER} hesabından ${complaint.contactEmail} adresine`);
    
    const info = await transporter.sendMail(mailOptions);
    console.log('E-posta gönderildi:', info.messageId);
    return true;
  } catch (error) {
    console.error('E-posta gönderilirken hata oluştu:', error);
    return false;
  }
};

module.exports = {
  sendStatusUpdateEmail
}; 