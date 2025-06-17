class DistrictData {
  static final Map<String, List<String>> izmirDistricts = {
    'Buca': [
      'Adatepe', 'Atatürk', 'Belenbaşı', 'Çamlıkule', 'Dicle', 'Dumlupınar',
      'Fırat', 'Gediz', 'Göksu', 'İnkılap', 'İnönü', 'Kozağaç', 'Kuruçeşme',
      'Menderes', 'Murathan', 'Mustafa Kemal', 'Seyhan', 'Vali Rahmi Bey', 'Yenigün', 'Yıldız'
    ],
    'Konak': [
      'Alsancak', 'Basmane', 'Göztepe', 'Hatay', 'Karataş', 'Karantina',
      'Kültürpark', 'Güzelyalı', 'Konak', 'Eşrefpaşa', 'Kadifekale', 'Kemeraltı'
    ],
    'Karşıyaka': [
      'Alaybey', 'Bostanlı', 'Dedebaşı', 'Donanmacı', 'Goncalar', 'Mavişehir',
      'Nergiz', 'Tuna', 'Yalı', 'Tersane', 'Bahçelievler', 'Bahariye'
    ],
    'Bornova': [
      'Altındağ', 'Atatürk', 'Çamdibi', 'Doğanlar', 'Evka 3', 'Evka 4',
      'Işıkkent', 'Kazımdirik', 'Kızılay', 'Mansuroglu', 'Pınarbaşı', 'Yeşilova'
    ],
    'Bayraklı': [
      'Adalet', 'Bayraklı', 'Cengizhan', 'Doğançay', 'Fuat Edip Baksı', 'Gümüşpala',
      'Manavkuyu', 'Onur', 'Osmangazi', 'Postacılar', 'Soğukkuyu', 'Yamanlar'
    ],
    'Çeşme': [
      'Alaçatı', 'Çiftlikköy', 'Dalyanköy', 'Germiyan', 'Ilıca', 'Karaköy',
      'Ovacık', 'Reisdere', 'Şifne'
    ],
    'Karabağlar': [
      'Aşık Veysel', 'Bahçelievler', 'Basın Sitesi', 'Bozyaka', 'Cennetçeşme', 'Esentepe',
      'Gazi', 'İhsan Alyanak', 'Limontepe', 'Özgür', 'Selvili', 'Uğur Mumcu', 'Uzundere', 'Yeşilyurt'
    ],
    'Gaziemir': [
      'Aktepe', 'Atıfbey', 'Binbaşı Reşatbey', 'Emrez', 'Gazi', 'Menderes',
      'Irmak', 'Sarnıç', 'Sevgi', 'Üniversite', 'Yeşil'
    ],
    'Balçova': [
      'Çetin Emeç', 'Eğitim', 'Fevzi Çakmak', 'İnciraltı', 'Korutürk',
      'Onur', 'Teleferik'
    ],
    'Çiğli': [
      'Ataşehir', 'Balatçık', 'Büyük Çiğli', 'Esentepe', 'Harmandalı', 'Karacaoğlan',
      'Küçük Çiğli', 'Maltepe', 'Sasalı', 'Yeni Mahalle'
    ],
  };

  static List<String> getDistrictList() {
    return izmirDistricts.keys.toList();
  }

  static List<String> getNeighborhoodsByDistrict(String district) {
    return izmirDistricts[district] ?? [];
  }
} 