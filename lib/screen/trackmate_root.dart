import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/trackmate_api.dart';

const brand = Color(0xFF087E78);
const ink = Color(0xFF172B3A);

class TrackMateRoot extends StatefulWidget {
  const TrackMateRoot({super.key});
  @override State<TrackMateRoot> createState() => _TrackMateRootState();
}
class _TrackMateRootState extends State<TrackMateRoot> {
  bool loading = true;
  @override void initState() { super.initState(); TrackMateApi.instance.restoreSession().then((_) { if (mounted) setState(() => loading = false); }); }
  @override Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return TrackMateApi.instance.currentUser == null ? const AuthScreen() : const DeliveryHomeScreen();
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override State<AuthScreen> createState() => _AuthScreenState();
}
class _AuthScreenState extends State<AuthScreen> {
  final name = TextEditingController(), email = TextEditingController(), phone = TextEditingController(), password = TextEditingController();
  String role = 'client'; bool register = false, busy = false;
  Future<void> submit() async {
    setState(() => busy = true);
    try {
      if (register) {
        await TrackMateApi.instance.register(fullName: name.text.trim(), email: email.text.trim(), phone: phone.text.trim(), password: password.text, role: role);
      } else {
        await TrackMateApi.instance.login(email: email.text.trim(), password: password.text, role: role);
      }
      if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const TrackMateRoot()), (_) => false);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')))); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Icon(Icons.local_shipping_rounded, color: brand, size: 54), const SizedBox(height: 12),
      const Text('Track-Mate', textAlign: TextAlign.center, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: ink)),
      const Text('Livraison simple, suivi en temps réel', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 30),
      SegmentedButton<String>(segments: const [ButtonSegment(value: 'client', label: Text('Client'), icon: Icon(Icons.person_outline)), ButtonSegment(value: 'driver', label: Text('Livreur'), icon: Icon(Icons.delivery_dining))], selected: {role}, onSelectionChanged: (v) => setState(() => role = v.first)),
      const SizedBox(height: 20),
      if (register) ...[TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom complet', prefixIcon: Icon(Icons.badge_outlined))), const SizedBox(height: 12), TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Téléphone (facultatif)', prefixIcon: Icon(Icons.phone))), const SizedBox(height: 12)],
      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.email_outlined))),
      const SizedBox(height: 12), TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Mot de passe', prefixIcon: Icon(Icons.lock_outline))),
      const SizedBox(height: 22), FilledButton(onPressed: busy ? null : submit, style: FilledButton.styleFrom(backgroundColor: brand, padding: const EdgeInsets.all(16)), child: busy ? const CircularProgressIndicator(color: Colors.white) : Text(register ? 'Créer mon compte' : 'Se connecter')),
      TextButton(onPressed: busy ? null : () => setState(() => register = !register), child: Text(register ? 'J’ai déjà un compte' : 'Créer un compte')),
    ]))))),
  );
}

class DeliveryHomeScreen extends StatefulWidget {
  const DeliveryHomeScreen({super.key});
  @override State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}
class _DeliveryHomeScreenState extends State<DeliveryHomeScreen> {
  List<Map<String, dynamic>> orders = [];
  bool busy = false;
  Timer? locationTimer;
  String? activeDriverOrder;
  @override void initState() { super.initState(); refresh(); }
  @override void dispose() { locationTimer?.cancel(); super.dispose(); }
  Future<void> refresh() async {
    try { final data = await TrackMateApi.instance.orders(); if (mounted) setState(() => orders = data); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }
  Future<Position> position() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw Exception('Activez la localisation GPS.');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) throw Exception('Permission GPS refusée.');
    return Geolocator.getCurrentPosition();
  }
  Future<void> createOrder() async {
    final item = TextEditingController(), pickup = TextEditingController(), delivery = TextEditingController(), lat = TextEditingController(), lng = TextEditingController();
    Position? here;
    try { here = await position(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); return; }
    if (!mounted) return;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Nouvelle livraison'), content: SingleChildScrollView(child: Column(children: [
      TextField(controller: item, decoration: const InputDecoration(labelText: 'Description du colis / commande')),
      TextField(controller: pickup, decoration: const InputDecoration(labelText: 'Adresse de récupération')),
      TextField(controller: delivery, decoration: const InputDecoration(labelText: 'Adresse de livraison')),
      TextField(controller: lat, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Latitude destination')),
      TextField(controller: lng, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Longitude destination')),
      const SizedBox(height: 8), const Text('Le point de récupération utilise votre GPS actuel.', style: TextStyle(fontSize: 12, color: Colors.black54)),
    ])), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Envoyer'))]));
    if (ok != true) return;
    try {
      await TrackMateApi.instance.createOrder(itemDescription: item.text.trim(), pickupAddress: pickup.text.trim().isEmpty ? 'Ma position actuelle' : pickup.text.trim(), pickupLatitude: here.latitude, pickupLongitude: here.longitude, deliveryAddress: delivery.text.trim(), deliveryLatitude: double.parse(lat.text), deliveryLongitude: double.parse(lng.text));
      await refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Commande enregistrée. Les livreurs peuvent la voir.')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }
  Future<void> accept(String id) async { try { await TrackMateApi.instance.acceptOrder(id); await refresh(); startLocationSharing(id); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); } }
  void startLocationSharing(String id) {
    locationTimer?.cancel(); activeDriverOrder = id;
    locationTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      try { final p = await position(); await TrackMateApi.instance.sendLocation(id, p.latitude, p.longitude, heading: p.heading, speed: p.speed); } catch (_) {}
    });
  }
  Future<void> advance(Map<String, dynamic> order) async {
    final id = order['id'].toString(), status = order['status'].toString();
    final next = status == 'assigned' ? 'picked_up' : status == 'picked_up' ? 'in_transit' : 'delivered';
    try {
      final p = await position();
      await TrackMateApi.instance.sendLocation(id, p.latitude, p.longitude, heading: p.heading, speed: p.speed);
      await TrackMateApi.instance.updateStatus(id, next);
      if (next == 'delivered') { locationTimer?.cancel(); activeDriverOrder = null; }
      await refresh();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }
  @override Widget build(BuildContext context) {
    final user = TrackMateApi.instance.currentUser!;
    final isClient = user['role'] == 'client';
    return Scaffold(
      appBar: AppBar(title: const Text('Track-Mate', style: TextStyle(fontWeight: FontWeight.w800)), actions: [IconButton(onPressed: refresh, icon: const Icon(Icons.refresh)), IconButton(onPressed: () async { await TrackMateApi.instance.logout(); if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const TrackMateRoot()), (_) => false); }, icon: const Icon(Icons.logout))]),
      floatingActionButton: isClient ? FloatingActionButton.extended(onPressed: createOrder, backgroundColor: brand, icon: const Icon(Icons.add), label: const Text('Nouvelle livraison')) : null,
      body: RefreshIndicator(onRefresh: refresh, child: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Bonjour, ${user['full_name'] ?? ''}', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
        Text(isClient ? 'Vos commandes et leur progression' : 'Missions disponibles et livraisons assignées', style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 20),
        if (orders.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('Aucune commande pour le moment.'))),
        ...orders.map((o) => _orderCard(o, isClient)),
      ])),
    );
  }
  Widget _orderCard(Map<String, dynamic> o, bool isClient) {
    final status = (o['status'] ?? 'pending').toString();
    final driverId = o['driver_id']?.toString();
    final mine = driverId == TrackMateApi.instance.currentUser?['id'];
    return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(o['id']?.toString() ?? 'Commande', style: const TextStyle(fontWeight: FontWeight.w800))), Chip(label: Text(status))]),
      Text(o['item_description']?.toString() ?? o['notes']?.toString() ?? 'Livraison'),
      const SizedBox(height: 8), Text('Départ : ${o['pickup_address'] ?? '—'}'), Text('Destination : ${o['delivery_address'] ?? '—'}'),
      if (!isClient && status == 'pending') Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: () => accept(o['id'].toString()), child: const Text('Accepter la mission'))),
      if (!isClient && mine && status != 'delivered') Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: () => advance(o), child: Text(status == 'assigned' ? 'Colis récupéré' : status == 'picked_up' ? 'Démarrer livraison' : 'Confirmer remise'))),
      if (isClient && driverId != null) Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () async { try { final data = await TrackMateApi.instance.tracking(o['id'].toString()); final loc = data['location']; if (mounted) showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Position du livreur'), content: Text('Latitude : ${loc['latitude']}\nLongitude : ${loc['longitude']}\nDernière mise à jour : ${loc['updated_at']}'))); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); } }, icon: const Icon(Icons.location_on), label: const Text('Voir position'))),
    ])));
  }
}
