import 'dart:ui'; // For ImageFilter.blur
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/features/auth/account_service.dart';
import 'package:myapp/features/auth/account_model.dart';
import 'package:myapp/features/drive/drive_notifier.dart';
import 'package:myapp/features/drive/file_model.dart';

enum ToolbarPosition {
  left,
  right,
}

void main() {
  runApp(const MyApp());
}

// A custom ChangeNotifier to manage theme settings (dark/light mode, accent colors, glassmorphism)
class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Color _accentColor = Colors.blue;
  Color get accentColor => _accentColor;

  bool _enableGlassmorphism = false;
  bool get enableGlassmorphism => _enableGlassmorphism;

  ToolbarPosition _toolbarPosition = ToolbarPosition.left;
  ToolbarPosition get toolbarPosition => _toolbarPosition;

  void toggleTheme(bool isDarkMode) {
    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setAccentColor(Color color) {
    _accentColor = color;
    notifyListeners();
  }

  void toggleGlassmorphism(bool enable) {
    _enableGlassmorphism = enable;
    notifyListeners();
  }

  void setToolbarPosition(ToolbarPosition position) {
    _toolbarPosition = position;
    notifyListeners();
  }
}

// Account Management Provider
class AuthNotifier with ChangeNotifier {
  Account? _currentAccount;
  Account? get currentAccount => _currentAccount;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  AuthNotifier() {
    _loadCurrentAccount();
  }

  Future<void> _loadCurrentAccount() async {
    _isLoading = true;
    notifyListeners();
    _currentAccount = await AccountService().getCurrentAccount();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await AccountService().login(email, password);
      _currentAccount = await AccountService().getCurrentAccount();
    } catch (e) {
      // Handle login error
      print("Login error: $e");
      _currentAccount = null;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> switchAccount(Account account) async {
    _isLoading = true;
    notifyListeners();
    await AccountService().setCurrentAccount(account);
    _currentAccount = await AccountService().getCurrentAccount();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addAccount(Account newAccount) async {
    await AccountService().addAccount(newAccount);
    _currentAccount = await AccountService().getCurrentAccount(); // Refresh current account if needed
    notifyListeners();
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    await AccountService().logout();
    _currentAccount = null;
    _isLoading = false;
    notifyListeners();
  }
}

final _router = GoRouter(
  redirect: (BuildContext context, GoRouterState state) async {
    final authNotifier = Provider.of<AuthNotifier>(context, listen: false);
    final loggedIn = authNotifier.currentAccount != null;
    final loggingIn = state.uri.path == '/';

    // If not logged in, and not on the login page, redirect to login.
    if (!loggedIn && !loggingIn) {
      return '/';
    }
    // If logged in, and on the login page, redirect to home.
    if (loggedIn && loggingIn) {
      return '/home';
    }
    // No redirect
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const DriveHomeScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/switch-account',
      builder: (context, state) => const AccountSwitcherScreen(),
    ),
    GoRoute(
      path: '/offline-files',
      builder: (context, state) => const OfflineFilesScreen(),
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthNotifier()),
        ChangeNotifierProvider(create: (_) => DriveNotifier()),
      ],
      child: Consumer3<ThemeProvider, AuthNotifier, DriveNotifier>(
        builder: (context, themeProvider, authNotifier, driveNotifier, child) {
          return MaterialApp.router(
            title: 'Foss Drive',
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: themeProvider.accentColor),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: themeProvider.accentColor, brightness: Brightness.dark),
              useMaterial3: true,
            ),
            routerConfig: _router,
          );
        },
      ),
    );
  }
}

// Placeholder Screens
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController(); // Dummy, not used for actual auth

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authNotifier = Provider.of<AuthNotifier>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Login to Foss Drive'),
              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password (Dummy)',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              authNotifier.isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () async {
                        try {
                          await authNotifier.login(_emailController.text, _passwordController.text);
                          if (authNotifier.currentAccount != null) {
                            context.go('/home');
                          }
                        } catch (e) {
                          // Show error message
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Login failed: ${e.toString()}')),
                          );
                        }
                      },
                      child: const Text('Login'),
                    ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () async {
                  // Simulate adding a new account
                  final newAccount = Account(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    email: 'user3@example.com',
                    name: 'User Three',
                  );
                  await authNotifier.addAccount(newAccount);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dummy account added: user3@example.com')),
                  );
                },
                child: const Text('Add Dummy Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DriveHomeScreen extends StatelessWidget {
  const DriveHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authNotifier = Provider.of<AuthNotifier>(context);
    final driveNotifier = Provider.of<DriveNotifier>(context);
    final themeProvider = Provider.of<ThemeProvider>(context); // Get ThemeProvider

    final currentAccount = authNotifier.currentAccount;

    Widget driveContent = driveNotifier.currentFolderItems.isEmpty
        ? const Center(child: Text('This folder is empty.'))
        : GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // Two items per row
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
              childAspectRatio: 1.0, // Make items square
            ),
            itemCount: driveNotifier.currentFolderItems.length,
            itemBuilder: (context, index) {
              final item = driveNotifier.currentFolderItems[index];
              return GestureDetector(
                onTap: () {
                  if (item.type == FileType.folder) {
                    driveNotifier.openFolder(item);
                  } else {
                    // Open file (dummy action)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Opening file: ${item.name}')),
                    );
                  }
                },
                onLongPress: () {
                  _showItemContextMenu(context, item, driveNotifier);
                },
                child: Card(
                  elevation: 2.0,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.type == FileType.folder
                            ? Icons.folder
                            : Icons.insert_drive_file,
                        size: 50,
                        color: item.type == FileType.folder
                            ? Colors.amber
                            : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        item.name,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.isOfflineAvailable)
                        const Icon(Icons.cloud_done, size: 16, color: Colors.green),
                    ],
                  ),
                ),
              );
            },
          );

    if (themeProvider.enableGlassmorphism) {
      driveContent = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.1)),
          child: driveContent,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Foss Drive Home'),
        leading: driveNotifier.currentParentId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => driveNotifier.goBack(),
              )
            : null,
      ),
      drawer: themeProvider.toolbarPosition == ToolbarPosition.left
          ? Drawer(
              child: _buildDrawerContent(context, authNotifier, driveNotifier, currentAccount),
            )
          : null,
      endDrawer: themeProvider.toolbarPosition == ToolbarPosition.right
          ? Drawer(
              child: _buildDrawerContent(context, authNotifier, driveNotifier, currentAccount),
            )
          : null,
      body: driveContent,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Show options for new file/folder
          _showNewItemOptions(context, driveNotifier);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDrawerContent(BuildContext context, AuthNotifier authNotifier, DriveNotifier driveNotifier, Account? currentAccount) {
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        DrawerHeader(
          decoration: const BoxDecoration(
            color: Colors.blue,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currentAccount?.name ?? 'Guest',
                style: const TextStyle(color: Colors.white, fontSize: 24),
              ),
              Text(
                currentAccount?.email ?? 'Not Logged In',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () async {
                  await authNotifier.logout();
                  context.go('/');
                },
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.account_circle),
          title: const Text('Switch Account'),
          onTap: () {
            context.go('/switch-account');
          },
        ),
        ListTile(
          leading: const Icon(Icons.upload_file),
          title: const Text('Upload File'),
          onTap: () {
            _showUploadFileDialog(context, driveNotifier);
          },
        ),
        ListTile(
          leading: const Icon(Icons.download),
          title: const Text('Download File (Select from list)'),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Long press a file to download.')),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.folder_open),
          title: const Text('Create Folder'),
          onTap: () {
            _showCreateFolderDialog(context, driveNotifier);
          },
        ),
        ListTile(
          leading: const Icon(Icons.offline_bolt),
          title: const Text('Offline Files'),
          onTap: () {
            context.go('/offline-files');
          },
        ),
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('Settings'),
          onTap: () {
            context.go('/settings');
          },
        ),
      ],
    );
  }

  void _showUploadFileDialog(BuildContext context, DriveNotifier driveNotifier) {
    final TextEditingController fileNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload File (Dummy)'),
        content: TextField(
          controller: fileNameController,
          decoration: const InputDecoration(hintText: 'Enter file name'),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (fileNameController.text.isNotEmpty) {
                await driveNotifier.uploadFile(fileNameController.text, [0, 1, 2]); // Dummy file bytes
                context.pop();
              }
            },
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  void _showCreateFolderDialog(BuildContext context, DriveNotifier driveNotifier) {
    final TextEditingController folderNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Folder'),
        content: TextField(
          controller: folderNameController,
          decoration: const InputDecoration(hintText: 'Enter folder name'),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (folderNameController.text.isNotEmpty) {
                await driveNotifier.createFolder(folderNameController.text);
                context.pop();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showItemContextMenu(BuildContext context, DriveItem item, DriveNotifier driveNotifier) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Details'),
                onTap: () {
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Details for ${item.name}')),
                  );
                },
              ),
              if (item.type != FileType.folder && item.downloadUrl != null)
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Download'),
                  onTap: () async {
                    context.pop();
                    await driveNotifier.downloadFile(item);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Downloading ${item.name}...')), 
                    );
                  },
                ),
              if (item.type != FileType.folder)
                ListTile(
                  leading: item.isOfflineAvailable ? const Icon(Icons.cloud_off) : const Icon(Icons.cloud_download),
                  title: item.isOfflineAvailable ? const Text('Remove from Offline') : const Text('Make Available Offline'),
                  onTap: () async {
                    context.pop();
                    await driveNotifier.toggleOfflineAvailability(item);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${item.name} offline status toggled.')),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showNewItemOptions(BuildContext context, DriveNotifier driveNotifier) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('New Folder'),
                onTap: () {
                  context.pop();
                  _showCreateFolderDialog(context, driveNotifier);
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('Upload File'),
                onTap: () {
                  context.pop();
                  _showUploadFileDialog(context, driveNotifier);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: themeProvider.themeMode == ThemeMode.dark,
            onChanged: (bool value) {
              themeProvider.toggleTheme(value);
            },
          ),
          SwitchListTile(
            title: const Text('Enable Glassmorphism Effect'),
            value: themeProvider.enableGlassmorphism,
            onChanged: (bool value) {
              themeProvider.toggleGlassmorphism(value);
            },
          ),
          ListTile(
            title: const Text('Accent Color'),
            trailing: DropdownButton<Color>(
              value: themeProvider.accentColor,
              onChanged: (Color? newColor) {
                if (newColor != null) {
                  themeProvider.setAccentColor(newColor);
                }
              },
              items: <Color>[
                Colors.blue,
                Colors.green,
                Colors.deepPurple, // Taro-like
                Colors.purple,
                // For custom, a color picker would be needed
              ].map<DropdownMenuItem<Color>>((Color value) {
                return DropdownMenuItem<Color>(
                  value: value,
                  child: CircleAvatar(backgroundColor: value, radius: 12),
                );
              }).toList(),
            ),
          ),
          ListTile(
            title: const Text('Toolbar Position'),
            trailing: DropdownButton<ToolbarPosition>(
              value: themeProvider.toolbarPosition,
              onChanged: (ToolbarPosition? newPosition) {
                if (newPosition != null) {
                  themeProvider.setToolbarPosition(newPosition);
                }
              },
              items: ToolbarPosition.values.map<DropdownMenuItem<ToolbarPosition>>((ToolbarPosition value) {
                return DropdownMenuItem<ToolbarPosition>(
                  value: value,
                  child: Text(value.toString().split('.').last.toUpperCase()),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class AccountSwitcherScreen extends StatelessWidget {
  const AccountSwitcherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authNotifier = Provider.of<AuthNotifier>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Switch Account')),
      body: FutureBuilder<List<Account>>(
        future: AccountService().getAccounts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No accounts found.'));
          } else {
            final accounts = snapshot.data!;
            return ListView.builder(
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final account = accounts[index];
                return ListTile(
                  title: Text(account.name),
                  subtitle: Text(account.email),
                  onTap: () async {
                    await authNotifier.switchAccount(account);
                    context.go('/home');
                  },
                  trailing: authNotifier.currentAccount?.id == account.id
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                );
              },
            );
          }
        },
      ),
    );
  }
}

class OfflineFilesScreen extends StatelessWidget {
  const OfflineFilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final driveNotifier = Provider.of<DriveNotifier>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Offline Files')),
      body: FutureBuilder<List<DriveItem>>(,
        future: driveNotifier.getOfflineFiles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No offline files found.'));
          } else {
            final offlineFiles = snapshot.data!;
            return ListView.builder(
              itemCount: offlineFiles.length,
              itemBuilder: (context, index) {
                final file = offlineFiles[index];
                return ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: Text(file.name),
                  subtitle: Text(
                    file.size != null ? '${(file.size! / 1024).toStringAsFixed(2)} KB' : 'N/A',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.cloud_off),
                    onPressed: () async {
                      await driveNotifier.toggleOfflineAvailability(file);
                      // Refresh the list after toggling offline status
                      (context as Element).markNeedsBuild(); // Force rebuild to update FutureBuilder
                    },
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Opening offline file: ${file.name}')),
                    );
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}
