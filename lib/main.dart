import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Claves para SharedPreferences
const String _kIsLoggedIn = 'isLoggedIn';
const String _kUserData = 'userData';
const String _kUsers = 'users';

// -----------------------------------------------------------------------------
// Servicio de persistencia
// -----------------------------------------------------------------------------
class SharedPreferencesService {
  // Registrar usuario
  static Future<void> registerUser(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> usersJson = prefs.getStringList(_kUsers) ?? [];
    final List<Map<String, dynamic>> users = usersJson
        .map((s) => jsonDecode(s) as Map<String, dynamic>)
        .toList();
    if (users.any((u) => u['username'] == username)) {
      throw Exception('El usuario ya existe');
    }
    users.add({'username': username, 'password': password});
    final updated = users.map((u) => jsonEncode(u)).toList();
    await prefs.setStringList(_kUsers, updated);
  }

  // Login
  static Future<bool> login(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final List<String> usersJson = prefs.getStringList(_kUsers) ?? [];
      final List<Map<String, dynamic>> users = usersJson
          .map((s) => jsonDecode(s) as Map<String, dynamic>)
          .toList();
      final found = users.firstWhere(
        (u) => u['username'] == username && u['password'] == password,
        orElse: () => {},
      );
      if (found.isNotEmpty) {
        await prefs.setBool(_kIsLoggedIn, true);
        await prefs.setString(_kUserData, username);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error en login: $e');
      return false;
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kIsLoggedIn);
    await prefs.remove(_kUserData);
  }

  static Future<bool> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kIsLoggedIn) ?? false;
  }

  static Future<String?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserData);
  }

  // Notes por usuario
  static Future<void> saveNote(String username, String note) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = 'notes_$username';
    final List<String> notes = prefs.getStringList(key) ?? [];
    notes.add(note);
    await prefs.setStringList(key, notes);
  }

  static Future<List<String>> getNotes(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = 'notes_$username';
    return prefs.getStringList(key) ?? [];
  }

  static Future<void> updateNotes(String username, List<String> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = 'notes_$username';
    await prefs.setStringList(key, notes);
  }
}

// -----------------------------------------------------------------------------
// App
// -----------------------------------------------------------------------------
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Persistencia (SharedPreferences)',
      theme: ThemeData(useMaterial3: true, primarySwatch: Colors.blue),
      home: FutureBuilder<bool>(
        future: SharedPreferencesService.checkLoginStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final logged = snapshot.data ?? false;
          return logged ? const HomePage() : const LoginPage();
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// LoginPage
// -----------------------------------------------------------------------------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final success = await SharedPreferencesService.login(
      _userController.text.trim(),
      _passwordController.text.trim(),
    );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Credenciales inválidas')));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inicio de sesión')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextFormField(
                  controller: _userController,
                  decoration: const InputDecoration(labelText: 'Usuario', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.isEmpty) ? 'Ingresa usuario' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.isEmpty) ? 'Ingresa contraseña' : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Text('ENTRAR'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterPage())),
                  child: const Text('No tienes cuenta? Registrate'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// RegisterPage
// -----------------------------------------------------------------------------
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await SharedPreferencesService.registerUser(_userController.text.trim(), _passwordController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registro exitoso')));
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error registro: ${e.toString()}')));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextFormField(
                  controller: _userController,
                  decoration: const InputDecoration(labelText: 'Usuario', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.isEmpty) ? 'Ingresa usuario' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.isEmpty) ? 'Ingresa contraseña' : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Registrarse'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// HomePage
// -----------------------------------------------------------------------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _loggedInUser = 'Usuario';
  List<String> _notes = [];
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadNotes(_loggedInUser);  // Pasar username
  }

  Future<void> _loadUser() async {
    final name = await SharedPreferencesService.getUserData();
    if (mounted) setState(() {
      _loggedInUser = name ?? 'Usuario';
      _loadNotes(_loggedInUser);  // Recargar notas con el usuario correcto
    });
  }

  Future<void> _loadNotes(String username) async {
    final notes = await SharedPreferencesService.getNotes(username);
    if (mounted) setState(() => _notes = notes.reversed.toList());
  }

  Future<void> _saveNote() async {
    final text = _noteController.text.trim();
    if (text.isNotEmpty) {
      await SharedPreferencesService.saveNote(_loggedInUser, text);
      _noteController.clear();
      await _loadNotes(_loggedInUser);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nota guardada')));
    }
  }

  Future<void> _editNote(int index) async {
    _editController.text = _notes[index];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar nota'),
          content: TextField(
            controller: _editController,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Edita tu nota...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                if (_editController.text.isNotEmpty) {
                  final updatedNotes = List<String>.from(_notes);
                  updatedNotes[index] = _editController.text;
                  await SharedPreferencesService.updateNotes(_loggedInUser, updatedNotes);
                  await _loadNotes(_loggedInUser);
                  if (mounted) Navigator.pop(context);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteNote(int index) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar nota'),
          content: const Text('¿Estás seguro de eliminar esta nota?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                final updatedNotes = List<String>.from(_notes)..removeAt(index);
                await SharedPreferencesService.updateNotes(_loggedInUser, updatedNotes);
                await _loadNotes(_loggedInUser);
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    await SharedPreferencesService.logout();
    if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Home - $_loggedInUser')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(_loggedInUser),
              accountEmail: const Text('Persistencia con SharedPreferences'),
              currentAccountPicture: const CircleAvatar(child: Icon(Icons.person)),
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Mostrar notificación'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Notificación'),
                    content: Text('Hola, $_loggedInUser'),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: _handleLogout,
            )
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bienvenido, $_loggedInUser', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Agregar nota', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(controller: _noteController, minLines: 1, maxLines: 3, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Escribe tu nota...')),
                    const SizedBox(height: 8),
                    ElevatedButton(onPressed: _saveNote, child: const Text('Guardar'))
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Notas guardadas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            if (_notes.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Text('No hay notas')))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _notes.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      title: Text(_notes[index]),
                      leading: const Icon(Icons.note),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editNote(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteNote(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Acción rápida'))),
        icon: const Icon(Icons.flash_on),
        label: const Text('Rápido'),
      ),
    );
  }
}