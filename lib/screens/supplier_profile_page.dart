import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/supplier.dart';

class SupplierProfilePage extends StatelessWidget {
  final Supplier supplier;

  const SupplierProfilePage({super.key, required this.supplier});

  Widget _buildProfileHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: (supplier.profileImageUrl != null &&
                    supplier.profileImageUrl!.isNotEmpty)
                ? NetworkImage(supplier.profileImageUrl!)
                : null,
            backgroundColor: Colors.grey,
            child: (supplier.profileImageUrl == null ||
                    supplier.profileImageUrl!.isEmpty)
                ? Text(
                    supplier.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 40, color: Colors.white),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  supplier.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  supplier.profession,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.attach_money, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      "${supplier.price.toStringAsFixed(0)} ${tr('currency')}",
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBioSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Text(
        supplier.bio,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _buildWebsiteSection(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(supplier.website),
      onTap: () {
        // Implementace otevření URL (např. pomocí url_launcher)
      },
    );
  }

  Widget _buildContactSection(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.phone),
      title: Text(supplier.contact),
    );
  }

  Widget _buildPortfolioSection(BuildContext context) {
    if (supplier.portfolioImages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(child: Text(tr('no_portfolio_available'))),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: supplier.portfolioImages.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemBuilder: (context, index) {
          return Image.network(
            supplier.portfolioImages[index],
            fit: BoxFit.cover,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(supplier.name),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(context),
            const Divider(),
            _buildBioSection(context),
            _buildWebsiteSection(context),
            _buildContactSection(context),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Text(
                tr('portfolio'),
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            _buildPortfolioSection(context),
          ],
        ),
      ),
    );
  }
}
