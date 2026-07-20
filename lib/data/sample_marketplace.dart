import '../models/marketplace_item.dart';

// PLACEHOLDER DATA — replace with real buy/sell posts once users start
// posting, or with your own seed listings at launch.
final List<MarketplaceItem> sampleMarketplaceItems = [
  const MarketplaceItem(
    id: 'm1',
    sellerId: 'sample',
    title: 'Bags of Cement (Dangote)',
    price: 'GHS 65 / bag',
    sellerPhone: '0244000011',
    description: 'Fresh stock, available for pickup or delivery nearby.',
    locationText: 'Mataheko',
    isApproved: true,
  ),
  const MarketplaceItem(
    id: 'm2',
    sellerId: 'sample',
    title: 'Fairly Used Sofa Set',
    price: 'GHS 800',
    sellerPhone: '0244000012',
    description: '5-seater, good condition, moving so must sell fast.',
    locationText: 'Afienya',
    isApproved: true,
  ),
  const MarketplaceItem(
    id: 'm3',
    sellerId: 'sample',
    title: 'Fresh Tilapia (Daily Catch)',
    price: 'GHS 20 / kg',
    sellerPhone: '0244000013',
    description: 'Straight from the pond, available every morning.',
    locationText: 'Afienya market',
    isApproved: true,
  ),
  const MarketplaceItem(
    id: 'm4',
    sellerId: 'sample',
    title: 'Samsung A14 (Used)',
    price: 'GHS 950',
    sellerPhone: '0244000014',
    description: 'Clean phone, no issues, charger included.',
    locationText: 'Mataheko junction',
    isApproved: true,
  ),
];