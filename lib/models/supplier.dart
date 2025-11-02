/// models/supplier.dart
library;

class Supplier {
  final String id;
  final String name;
  final String profession;
  final String region;
  final String district;
  final double price;
  final String website;
  final String contact;
  final String? profileImageUrl;
  final String bio;
  final List<String> portfolioImages;

  Supplier({
    required this.id,
    required this.name,
    required this.profession,
    required this.region,
    required this.district,
    required this.price,
    required this.website,
    required this.contact,
    this.profileImageUrl,
    required this.bio,
    required this.portfolioImages,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] as String,
      name: json['name'] as String,
      profession: json['profession'] as String? ?? '',
      region: json['region'] as String? ?? '',
      district: json['district'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      website: json['website'] as String? ?? '',
      contact: json['contact'] as String? ?? '',
      profileImageUrl: json['profileImageUrl'] as String?,
      bio: json['bio'] as String? ?? '',
      portfolioImages:
          List<String>.from(json['portfolioImages'] as List<dynamic>? ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'profession': profession,
      'region': region,
      'district': district,
      'price': price,
      'website': website,
      'contact': contact,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'portfolioImages': portfolioImages,
    };
  }

  Supplier copyWith({
    String? id,
    String? name,
    String? profession,
    String? region,
    String? district,
    double? price,
    String? website,
    String? contact,
    String? profileImageUrl,
    String? bio,
    List<String>? portfolioImages,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      profession: profession ?? this.profession,
      region: region ?? this.region,
      district: district ?? this.district,
      price: price ?? this.price,
      website: website ?? this.website,
      contact: contact ?? this.contact,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      portfolioImages: portfolioImages ?? this.portfolioImages,
    );
  }
}
