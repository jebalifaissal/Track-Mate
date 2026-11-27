import 'package:delivery_boy_app/provider/current_location_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum TrackMateRole { customer, merchant, driver }

enum DemoOrderStatus { pending, accepted, pickedUp, onTheWay, delivered }

class _DemoOrder {
  _DemoOrder({
    required this.id,
    required this.customer,
    required this.merchant,
    required this.item,
    required this.amount,
    this.status = DemoOrderStatus.pending,
  });

  final String id;
  final String customer;
  final String merchant;
  final String item;
  final double amount;
  DemoOrderStatus status;
}

class CommercialHomeScreen extends StatefulWidget {
  const CommercialHomeScreen({super.key});

  @override
  State<CommercialHomeScreen> createState() => _CommercialHomeScreenState();
}

class _CommercialHomeScreenState extends State<CommercialHomeScreen> {
  TrackMateRole _role = TrackMateRole.driver;
  int _tab = 0;
  bool _isOnline = true;
  final List<_DemoOrder> _orders = [
    _DemoOrder(id: 'TM-2048', customer: 'Amira Ben Ali', merchant: 'Fresh Market', item: 'Panier de courses', amount: 42.500, status: DemoOrderStatus.onTheWay),
    _DemoOrder(id: 'TM-2047', customer: 'Yassine Trabelsi', merchant: 'Tech Store', item: 'Accessoires mobile', amount: 89.000, status: DemoOrderStatus.accepted),
    _DemoOrder(id: 'TM-2046', customer: 'Meriem Saidi', merchant: 'Coffee House', item: 'Commande café', amount: 18.000, status: DemoOrderStatus.delivered),
  ];

  String get _roleLabel {
    switch (_role) {
      case TrackMateRole.customer:
        return 'Client';
      case TrackMateRole.merchant:
        return 'Commerçant';
      case TrackMateRole.driver:
        return 'Livreur';
    }
  }

  String get _pageTitle => const ['Accueil', 'Commandes', 'Suivi', 'Portefeuille', 'Profil'][_tab];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: const Color(0xFFE8F5F2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF087E78)),
            ),
            const SizedBox(width: 10),
            const Text('Track-Mate', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF172B3A), letterSpacing: -.4)),
          ],
        ),
        actions: [
          PopupMenuButton<TrackMateRole>(
            tooltip: 'Changer de profil',
            onSelected: (value) => setState(() { _role = value; _tab = 0; }),
            itemBuilder: (context) => const [
              PopupMenuItem(value: TrackMateRole.customer, child: Text('Espace client')),
              PopupMenuItem(value: TrackMateRole.merchant, child: Text('Espace commerçant')),
              PopupMenuItem(value: TrackMateRole.driver, child: Text('Espace livreur')),
            ],
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFF0F4F6), borderRadius: BorderRadius.circular(24)),
              child: Row(children: [const Icon(Icons.swap_horiz_rounded, size: 17), const SizedBox(width: 5), Text(_roleLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), const Icon(Icons.keyboard_arrow_down, size: 17)]),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: IndexedStack(
          index: _tab,
          children: [
            _buildDashboard(),
            _buildOrders(),
            _buildTracking(),
            _buildWallet(),
            _buildProfile(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 70,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE3F2EF),
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard_rounded), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Commandes'),
          NavigationDestination(icon: Icon(Icons.location_on_outlined), selectedIcon: Icon(Icons.location_on_rounded), label: 'Suivi'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Revenus'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final delivered = _orders.where((o) => o.status == DemoOrderStatus.delivered).length;
    final active = _orders.where((o) => o.status != DemoOrderStatus.delivered).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
      children: [
        Text(_greeting(), style: const TextStyle(color: Color(0xFF718096), fontSize: 13)),
        const SizedBox(height: 5),
        Text(_role == TrackMateRole.customer ? 'Vos livraisons,\nen toute simplicité.' : _role == TrackMateRole.merchant ? 'Pilotez votre activité\nen un coup d’œil.' : 'Prêt pour votre\nprochaine livraison ?', style: const TextStyle(fontSize: 27, height: 1.15, fontWeight: FontWeight.w800, color: Color(0xFF172B3A))),
        const SizedBox(height: 18),
        if (_role == TrackMateRole.driver) _onlineCard(),
        if (_role == TrackMateRole.customer) _customerHero(),
        if (_role == TrackMateRole.merchant) _merchantHero(),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _metricCard('Commandes', '${_orders.length}', Icons.inventory_2_outlined, const Color(0xFFEAF2FF), const Color(0xFF3973C6))),
          const SizedBox(width: 10),
          Expanded(child: _metricCard(_role == TrackMateRole.driver ? 'Terminées' : 'En cours', _role == TrackMateRole.driver ? '$delivered' : '$active', Icons.check_circle_outline, const Color(0xFFE5F5EF), const Color(0xFF16865F))),
          const SizedBox(width: 10),
          Expanded(child: _metricCard('Aujourd’hui', '3', Icons.trending_up_rounded, const Color(0xFFFFF2E5), const Color(0xFFD9822B))),
        ]),
        const SizedBox(height: 25),
        _sectionHeader(_role == TrackMateRole.customer ? 'Vos commandes récentes' : 'Activité récente', 'Tout voir', () => setState(() => _tab = 1)),
        const SizedBox(height: 12),
        ..._orders.take(2).map(_orderPreview),
        const SizedBox(height: 18),
        _sectionHeader('Accès rapide', null, null),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _quickAction(Icons.receipt_long_outlined, 'Commandes', () => setState(() => _tab = 1))),
          const SizedBox(width: 10),
          Expanded(child: _quickAction(Icons.map_outlined, 'Suivi GPS', () => setState(() => _tab = 2))),
          const SizedBox(width: 10),
          Expanded(child: _quickAction(Icons.account_balance_wallet_outlined, 'Revenus', () => setState(() => _tab = 3))),
        ]),
      ],
    );
  }

  String _greeting() => 'BONJOUR • ESPACE $_roleLabel'.toUpperCase();

  Widget _onlineCard() => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(color: _isOnline ? const Color(0xFF087E78) : const Color(0xFF34495E), borderRadius: BorderRadius.circular(20)),
    child: Row(children: [
      Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.delivery_dining, color: Colors.white, size: 25)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_isOnline ? 'Vous êtes en ligne' : 'Vous êtes hors ligne', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 3),
        Text(_isOnline ? 'Vous pouvez recevoir des missions' : 'Activez votre disponibilité', style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 11)),
      ])),
      Switch(value: _isOnline, activeColor: Colors.white, activeTrackColor: const Color(0xFF54B8A5), onChanged: (v) => setState(() => _isOnline = v)),
    ]),
  );

  Widget _customerHero() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF087E78), Color(0xFF12A18F)]), borderRadius: BorderRadius.circular(20)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Besoin d’une livraison ?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      Text('Commandez auprès de vos commerces préférés.', style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 12)),
      const SizedBox(height: 15),
      Align(alignment: Alignment.centerLeft, child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF087E78)), onPressed: _createOrder, icon: const Icon(Icons.add), label: const Text('Nouvelle commande'))),
    ]),
  );

  Widget _merchantHero() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: const Color(0xFF172B3A), borderRadius: BorderRadius.circular(20)),
    child: Row(children: [
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Espace professionnel', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)), SizedBox(height: 5), Text('Gérez les commandes et suivez vos ventes.', style: TextStyle(color: Colors.white70, fontSize: 12))])),
      Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 26)),
    ]),
  );

  Widget _metricCard(String title, String value, IconData icon, Color bg, Color fg) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE9EEF2))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 32, height: 32, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: fg, size: 18)),
      const SizedBox(height: 12),
      Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Color(0xFF172B3A))),
      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xFF718096))),
    ]),
  );

  Widget _buildOrders() {
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(_role == TrackMateRole.customer ? 'Vos commandes' : _role == TrackMateRole.merchant ? 'Commandes de votre boutique' : 'Missions disponibles', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF172B3A))),
      const SizedBox(height: 6),
      const Text('Consultez et gérez les étapes de livraison.', style: TextStyle(color: Color(0xFF718096), fontSize: 13)),
      const SizedBox(height: 18),
      if (_role == TrackMateRole.customer) FilledButton.icon(onPressed: _createOrder, icon: const Icon(Icons.add), label: const Text('Créer une commande')),
      if (_role == TrackMateRole.customer) const SizedBox(height: 12),
      ..._orders.map(_orderCard),
      const SizedBox(height: 12),
      _demoNotice(),
    ]);
  }

  Widget _orderCard(_DemoOrder order) {
    final status = _statusLabel(order.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE8EDF1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(order.id, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF172B3A)))), _statusChip(status)]),
        const SizedBox(height: 12),
        Text(order.item, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text('${order.customer} • ${order.merchant}', style: const TextStyle(color: Color(0xFF718096), fontSize: 12)),
        const SizedBox(height: 12),
        Row(children: [Text('${order.amount.toStringAsFixed(3)} TND', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF087E78))), const Spacer(), if (_role != TrackMateRole.customer && order.status != DemoOrderStatus.delivered) TextButton(onPressed: () => _advanceOrder(order), child: Text(_role == TrackMateRole.driver ? 'Mettre à jour' : 'Préparer'))]),
      ]),
    );
  }

  Widget _orderPreview(_DemoOrder order) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
    child: Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFEAF5F2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF087E78))),
      const SizedBox(width: 11),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(order.item, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), Text(order.id, style: const TextStyle(color: Color(0xFF718096), fontSize: 11))])),
      _statusChip(_statusLabel(order.status)),
    ]),
  );

  Widget _buildTracking() {
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Suivi & localisation', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF172B3A))),
      const SizedBox(height: 6),
      const Text('Position actuelle de cet appareil.', style: TextStyle(color: Color(0xFF718096), fontSize: 13)),
      const SizedBox(height: 18),
      Consumer<CurrentLocationProvider>(builder: (context, location, _) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE8EDF1))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.my_location, color: Color(0xFF087E78)), const SizedBox(width: 9), const Expanded(child: Text('Votre position GPS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))), IconButton(onPressed: location.refreshLocation, icon: const Icon(Icons.refresh))]),
          if (location.isLoading) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          if (!location.isLoading && location.errorMessage.isNotEmpty) Text(location.errorMessage, style: const TextStyle(color: Colors.red, fontSize: 12)),
          if (!location.isLoading && location.errorMessage.isEmpty) ...[
            const SizedBox(height: 8),
            Text('Latitude  ${location.currentLocation.latitude.toStringAsFixed(5)}', style: const TextStyle(fontSize: 13)),
            Text('Longitude ${location.currentLocation.longitude.toStringAsFixed(5)}', style: const TextStyle(fontSize: 13)),
          ],
          const SizedBox(height: 12),
          const Text('La position est lue sur cet appareil. Le partage en temps réel avec le client nécessite une API et un serveur.', style: TextStyle(color: Color(0xFF718096), fontSize: 11, height: 1.4)),
        ]),
      )),
      const SizedBox(height: 16),
      _sectionHeader('Progression des livraisons', null, null),
      const SizedBox(height: 10),
      ..._orders.where((o) => o.status != DemoOrderStatus.delivered).map((o) => _orderPreview(o)),
      _demoNotice(),
    ]);
  }

  Widget _buildWallet() => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('Portefeuille', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF172B3A))),
    const SizedBox(height: 6),
    const Text('Vue de démonstration des revenus et paiements.', style: TextStyle(color: Color(0xFF718096), fontSize: 13)),
    const SizedBox(height: 18),
    Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF172B3A), Color(0xFF087E78)]), borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('SOLDE ESTIMÉ', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1)),
      const SizedBox(height: 8),
      const Text('248,500 TND', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
      const SizedBox(height: 18),
      const Row(children: [Icon(Icons.trending_up, color: Colors.white70, size: 18), SizedBox(width: 7), Text('+12,5 % cette semaine', style: TextStyle(color: Colors.white, fontSize: 12))]),
    ])),
    const SizedBox(height: 20),
    Row(children: [Expanded(child: _metricCard('Gains du mois', '820 TND', Icons.payments_outlined, const Color(0xFFE5F5EF), const Color(0xFF16865F))), const SizedBox(width: 12), Expanded(child: _metricCard('Livraisons', '32', Icons.local_shipping_outlined, const Color(0xFFEAF2FF), const Color(0xFF3973C6)))]),
    const SizedBox(height: 22),
    _sectionHeader('Transactions récentes', null, null),
    const SizedBox(height: 10),
    _transactionRow('Livraison TM-2046', '+ 8,000 TND', Icons.check_circle_outline),
    _transactionRow('Commission plateforme', '- 1,200 TND', Icons.account_balance_outlined),
    _transactionRow('Livraison TM-2045', '+ 6,500 TND', Icons.check_circle_outline),
    const SizedBox(height: 12),
    _demoNotice(),
  ]);

  Widget _transactionRow(String title, String amount, IconData icon) => ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: const Color(0xFFEAF5F2), child: Icon(icon, color: const Color(0xFF087E78), size: 19)), title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), trailing: Text(amount, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)));

  Widget _buildProfile() => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('Mon profil', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF172B3A))),
    const SizedBox(height: 18),
    Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Column(children: [
      const CircleAvatar(radius: 38, backgroundColor: Color(0xFFE3F2EF), child: Icon(Icons.person, size: 42, color: Color(0xFF087E78))),
      const SizedBox(height: 10),
      const Text('Utilisateur Track-Mate', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      Text(_roleLabel, style: const TextStyle(color: Color(0xFF718096))),
      const SizedBox(height: 15),
      const Divider(),
      _profileItem(Icons.phone_outlined, 'Téléphone', '+216 XX XXX XXX'),
      _profileItem(Icons.email_outlined, 'E-mail', 'utilisateur@example.com'),
      _profileItem(Icons.location_on_outlined, 'Zone', 'Tunisie'),
    ])),
    const SizedBox(height: 16),
    _profileAction(Icons.language, 'Langue', 'Français'),
    _profileAction(Icons.notifications_none, 'Notifications', 'À configurer'),
    _profileAction(Icons.help_outline, 'Centre d’aide', 'Support Track-Mate'),
    const SizedBox(height: 12),
    _demoNotice(),
  ]);

  Widget _profileItem(IconData icon, String label, String value) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(icon, color: const Color(0xFF087E78)), title: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF718096))), subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)));
  Widget _profileAction(IconData icon, String title, String subtitle) => Card(color: Colors.white, elevation: 0, child: ListTile(leading: Icon(icon, color: const Color(0xFF087E78)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)), trailing: const Icon(Icons.chevron_right)));

  Widget _quickAction(IconData icon, String label, VoidCallback action) => InkWell(onTap: action, borderRadius: BorderRadius.circular(15), child: Container(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: Column(children: [Icon(icon, color: const Color(0xFF087E78), size: 23), const SizedBox(height: 8), Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))])));
  Widget _sectionHeader(String title, String? action, VoidCallback? onTap) => Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF172B3A)))), if (action != null) TextButton(onPressed: onTap, child: Text(action))]);
  Widget _statusChip(String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFEAF5F2), borderRadius: BorderRadius.circular(20)), child: Text(text, style: const TextStyle(color: Color(0xFF087E78), fontSize: 10, fontWeight: FontWeight.w800)));
  Widget _demoNotice() => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFF6E8), borderRadius: BorderRadius.circular(12)), child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline, color: Color(0xFFB7791F), size: 17), SizedBox(width: 8), Expanded(child: Text('Mode démonstration : ces commandes et montants sont locaux et ne représentent pas des transactions réelles.', style: TextStyle(color: Color(0xFF805B20), fontSize: 11, height: 1.4)))]));
  
  String _statusLabel(DemoOrderStatus status) {
    switch (status) {
      case DemoOrderStatus.pending: return 'En attente';
      case DemoOrderStatus.accepted: return 'Acceptée';
      case DemoOrderStatus.pickedUp: return 'Récupérée';
      case DemoOrderStatus.onTheWay: return 'En livraison';
      case DemoOrderStatus.delivered: return 'Livrée';
    }
  }

  void _advanceOrder(_DemoOrder order) {
    setState(() {
      switch (order.status) {
        case DemoOrderStatus.pending: order.status = DemoOrderStatus.accepted; break;
        case DemoOrderStatus.accepted: order.status = DemoOrderStatus.pickedUp; break;
        case DemoOrderStatus.pickedUp: order.status = DemoOrderStatus.onTheWay; break;
        case DemoOrderStatus.onTheWay: order.status = DemoOrderStatus.delivered; break;
        case DemoOrderStatus.delivered: break;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Statut de ${order.id} : ${_statusLabel(order.status)}')));
  }

  Future<void> _createOrder() async {
    final itemController = TextEditingController();
    final result = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Nouvelle commande'),
      content: TextField(controller: itemController, autofocus: true, decoration: const InputDecoration(labelText: 'Que souhaitez-vous commander ?', hintText: 'Ex. : Courses alimentaires')),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(dialogContext, itemController.text.trim()), child: const Text('Créer'))],
    ));
    if (!mounted) return;
    if (result == null || result.isEmpty) { itemController.dispose(); return; }
    setState(() {
      _orders.insert(0, _DemoOrder(id: 'TM-${2050 + _orders.length}', customer: 'Vous', merchant: 'Commerce partenaire', item: result, amount: 25.000));
      _tab = 1;
    });
    itemController.dispose();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Commande de démonstration créée.')));
  }
}
