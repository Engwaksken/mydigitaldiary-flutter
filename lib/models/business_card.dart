class BusinessCard {
  final int? id;
  final String name;
  final String? title;
  final String? company;
  final String? phone;
  final String? whatsappPhone;
  final String? email;
  final String? website;
  final String? address;
  final String? bio;
  final Map<String, dynamic> socialLinks;
  final String? photoUrl;
  final String? publicUrl;
  final String? qrCodeUrl;
  final bool isPublished;
  final String cardColor;
  final String cardColorSecondary;

  BusinessCard({
    this.id,
    required this.name,
    this.title,
    this.company,
    this.phone,
    this.whatsappPhone,
    this.email,
    this.website,
    this.address,
    this.bio,
    this.socialLinks = const {},
    this.photoUrl,
    this.publicUrl,
    this.qrCodeUrl,
    this.isPublished = true,
    this.cardColor = '#00897B',
    this.cardColorSecondary = '#73BEB6',
  });

  factory BusinessCard.fromJson(Map<String, dynamic> json) => BusinessCard(
        id: json['id'],
        name: json['name'] ?? '',
        title: json['title'],
        company: json['company'],
        phone: json['phone'],
        whatsappPhone: json['whatsapp_phone'],
        email: json['email'],
        website: json['website'],
        address: json['address'],
        bio: json['bio'],
        socialLinks: json['social_links'] != null
            ? Map<String, dynamic>.from(json['social_links'])
            : {},
        photoUrl: json['photo_url'],
        publicUrl: json['public_url'],
        qrCodeUrl: json['qr_code_url'],
        isPublished: json['is_published'] ?? true,
        cardColor: json['card_color'] ?? '#00897B',
        cardColorSecondary: json['card_color_secondary'] ?? '#73BEB6',
      );

  Map<String, String> toFormFields() => {
        'name': name,
        if (title != null) 'title': title!,
        if (company != null) 'company': company!,
        if (phone != null) 'phone': phone!,
        if (whatsappPhone != null) 'whatsapp_phone': whatsappPhone!,
        if (email != null) 'email': email!,
        if (website != null) 'website': website!,
        if (address != null) 'address': address!,
        if (bio != null) 'bio': bio!,
        if (socialLinks['facebook'] != null)
          'social_facebook': socialLinks['facebook'],
        if (socialLinks['twitter'] != null)
          'social_twitter': socialLinks['twitter'],
        if (socialLinks['linkedin'] != null)
          'social_linkedin': socialLinks['linkedin'],
        if (socialLinks['instagram'] != null)
          'social_instagram': socialLinks['instagram'],
        'card_color': cardColor,
        'card_color_secondary': cardColorSecondary,
      };
}
