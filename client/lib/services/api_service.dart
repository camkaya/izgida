import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http_parser/http_parser.dart';
import '../models/complaint.dart';
import '../models/business.dart';

class ApiService {
  
  static const String baseUrl = 'http:
  
  static Future<Complaint> submitComplaint({
    required String category,
    required String businessName,
    required String description,
    required String contactEmail,
    String? district,
    String? neighborhood,
    LatLng? location,
    List<File>? images,
  }) async {
    try {
      
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/complaints'),
      );
      
      request.fields['category'] = category;
      request.fields['businessName'] = businessName;
      
      final sb = StringBuffer();
      sb.writeln('İşletme Adı: $businessName');
      if (district != null) {
        sb.writeln('İlçe: $district');
        request.fields['district'] = district;
      }
      if (neighborhood != null) {
        sb.writeln('Mahalle: $neighborhood');
        request.fields['neighborhood'] = neighborhood;
      }
      if (location != null) {
        sb.writeln('Konum: ${location.latitude}, ${location.longitude}');
      }
      sb.writeln();
      sb.write(description);
      
      request.fields['description'] = sb.toString();
      request.fields['contactEmail'] = contactEmail;
      
      if (location != null) {
        request.fields['location[lat]'] = location.latitude.toString();
        request.fields['location[lng]'] = location.longitude.toString();
      }
      
      request.fields['updateBusinessScore'] = 'true';
      
      if (images != null && images.isNotEmpty) {
        int index = 0;
        for (final image in images) {
          final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}_$index.jpg';
          final multipartFile = await http.MultipartFile.fromPath(
            'images',
            image.path,
            filename: fileName,
            contentType: MediaType('image', 'jpeg'),
          );
          request.files.add(multipartFile);
          index++;
        }
      }
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final complaint = Complaint.fromJson(responseData);
        
        try {
          await http.post(
            Uri.parse('$baseUrl/scores/update'),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          
        }
        
        return complaint;
      } else {
        throw Exception('Gıda şikayeti gönderilemedi: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Gıda şikayeti gönderilirken hata oluştu: $e');
    }
  }
  
  static Future<List<Complaint>> getComplaints() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/complaints'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Complaint.fromJson(json)).toList();
      } else {
        throw Exception('Şikayetler alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Şikayetler alınırken hata oluştu: $e');
    }
  }
  
  static Future<Complaint> getComplaint(String id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/complaints/$id'));
      
      if (response.statusCode == 200) {
        return Complaint.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Şikayet alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Şikayet alınırken hata oluştu: $e');
    }
  }
  
  static Future<Complaint> updateComplaintStatus(String id, String status, {String? adminMessage}) async {
    try {
      
      final Map<String, dynamic> requestBody = {
        'status': status,
        'updateBusinessScore': true, 
      };
      
      if (adminMessage != null) {
        requestBody['adminMessage'] = adminMessage;
      }
      
      final response = await http.patch(
        Uri.parse('$baseUrl/complaints/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final complaint = Complaint.fromJson(jsonDecode(response.body));
        
        try {
          await http.post(
            Uri.parse('$baseUrl/scores/update'),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          
        }
        
        return complaint;
      } else {
        
        String errorMessage;
        try {
          final errorResponse = jsonDecode(response.body);
          errorMessage = errorResponse['message'] ?? 'Bilinmeyen hata';
        } catch (e) {
          errorMessage = response.body;
        }
        
        throw Exception('Şikayet durumu güncellenemedi (${response.statusCode}): $errorMessage');
      }
    } catch (e) {
      throw Exception('Şikayet durumu güncellenirken hata oluştu: $e');
    }
  }
  
  static Future<List<Business>> getBusinesses() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/scores'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Business.fromJson(json)).toList();
      } else {
        throw Exception('İşletmeler alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('İşletmeler alınırken hata oluştu: $e');
    }
  }
  
  static Future<List<Complaint>> getBusinessComplaints(String businessId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/scores/business/$businessId/complaints'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Complaint.fromJson(json)).toList();
      } else {
        throw Exception('İşletme şikayetleri alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('İşletme şikayetleri alınırken hata oluştu: $e');
    }
  }
  
  static Future<void> updateBusinessScores() async {
    try {
      await http.post(
        Uri.parse('$baseUrl/scores/update'),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      throw Exception('İşletme puanları güncellenirken hata oluştu: $e');
    }
  }
  
  static Future<bool> isServerOnline() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
} 