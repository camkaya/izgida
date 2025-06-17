import 'package:google_maps_flutter/google_maps_flutter.dart';

class Complaint {
  final String? id;
  final String description;
  final String contactEmail;
  final String status;
  final DateTime createdAt;
  final String category;
  final String businessName;
  final String? district;
  final String? neighborhood;
  final LatLng? location;
  final List<String>? imageUrls;
  final String? adminMessage;

  Complaint({
    this.id,
    required this.description,
    required this.contactEmail,
    required this.category,
    required this.businessName,
    this.district,
    this.neighborhood,
    this.location,
    this.status = 'pending',
    this.imageUrls,
    this.adminMessage,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Complaint.fromJson(Map<String, dynamic> json) {
    
    String extractedCategory = json['category'] ?? 'Diğer';
    String businessName = json['businessName'] ?? '';
    String description = json['description'] ?? '';
    String? district = json['district'];
    String? neighborhood = json['neighborhood'];
    
    if ((json['businessName'] == null || json['category'] == null) && description.isNotEmpty) {
      final lines = description.split('\n');
      
      for (final line in lines) {
        if (line.startsWith('İşletme Adı:')) {
          businessName = line.replaceFirst('İşletme Adı:', '').trim();
        } else if (line.startsWith('İlçe:')) {
          district = line.replaceFirst('İlçe:', '').trim();
        } else if (line.startsWith('Mahalle:')) {
          neighborhood = line.replaceFirst('Mahalle:', '').trim();
        }
      }
    }
    
    LatLng? location;
    if (json['location'] != null) {
      try {
        final lat = json['location']['lat'];
        final lng = json['location']['lng'];
        if (lat != null && lng != null) {
          location = LatLng(lat.toDouble(), lng.toDouble());
        }
      } catch (e) {
        
      }
    } else {
      
      String? locationStr;
      final lines = description.split('\n');
      for (final line in lines) {
        if (line.startsWith('Konum:')) {
          locationStr = line.replaceFirst('Konum:', '').trim();
          
          if (locationStr.contains(',')) {
            final coords = locationStr.split(',');
            if (coords.length == 2) {
              try {
                final lat = double.parse(coords[0].trim());
                final lng = double.parse(coords[1].trim());
                location = LatLng(lat, lng);
              } catch (e) {
                
              }
            }
          }
        }
      }
    }

    String cleanDescription = description;
    final descriptionLines = description.split('\n');
    int startIndex = 0;
    
    for (int i = 0; i < descriptionLines.length; i++) {
      if (descriptionLines[i].isEmpty && i > 0) {
        startIndex = i + 1;
        break;
      }
    }
    
    if (startIndex > 0 && startIndex < descriptionLines.length) {
      cleanDescription = descriptionLines.sublist(startIndex).join('\n');
    }

    return Complaint(
      id: json['_id'],
      description: cleanDescription,
      contactEmail: json['contactEmail'],
      status: json['status'] ?? 'pending',
      category: extractedCategory,
      businessName: businessName,
      district: district,
      neighborhood: neighborhood,
      location: location,
      adminMessage: json['adminMessage'],
      imageUrls: json['imageUrls'] != null 
        ? List<String>.from(json['imageUrls']) 
        : null,
      createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt']) 
        : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    
    String formattedDescription = description;
      final sb = StringBuffer();
    sb.writeln('İşletme Adı: $businessName');
    if (district != null) {
      sb.writeln('İlçe: $district');
    }
    if (neighborhood != null) {
      sb.writeln('Mahalle: $neighborhood');
    }
    if (location != null) {
      sb.writeln('Konum: ${location!.latitude}, ${location!.longitude}');
    }
    sb.writeln();
    sb.write(description);
    formattedDescription = sb.toString();
    
    final Map<String, dynamic> data = {
      'category': category,
      'businessName': businessName,
      'description': formattedDescription,
      'contactEmail': contactEmail,
      'status': status,
      'district': district,
      'neighborhood': neighborhood,
    };
    
    if (location != null) {
      data['location'] = {
        'lat': location!.latitude,
        'lng': location!.longitude
      };
    }
    
    if (adminMessage != null) {
      data['adminMessage'] = adminMessage;
    }
    
    if (imageUrls != null && imageUrls!.isNotEmpty) {
      data['imageUrls'] = imageUrls;
    }
    
    return data;
  }
} 