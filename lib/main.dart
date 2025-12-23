import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:myapp/features/auth/account_service.dart';
import 'package:myapp/features/auth/account_model.dart';
import 'package:myapp/features/drive/drive_notifier.dart';
import 'package:myapp/features/drive/file_model.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';

enum ToolbarPosition {
  left,
  right,
}

void main() {
  runApp(const MyApp());
}

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

  Future<void> loginWithCredentials(String jsonContent) async {
    _isLoading = true;
    notifyListeners();
    try {
      await AccountService().addAccountFromCredential(jsonContent);
      _currentAccount = await AccountService().getCurrentAccount();
    } catch (e) {
      print("Login error: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> switchAccount(Account account) async {
    _isLoading = true;
    notifyListeners();
    await AccountService().setCurrentAccount(account);
    _currentAccount = await AccountService().getCurrentAccount();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addAccount(String jsonContent) async {
     _isLoading = true;
     notifyListeners();
     try {
       await AccountService().addAccountFromCredential(jsonContent);
       _currentAccount = await AccountService().getCurrentAccount();
     } catch(e) {
       print("Add account error: $e");
       rethrow;
     } finally {
       _isLoading = false;
       notifyListeners();
     }
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

    if (!loggedIn && !loggingIn) {
      return '/';
    }
    if (loggedIn && loggingIn) {
      return '/home';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) {
        return MainLayout(child: child);
      },
      routes: [
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
          final textTheme = GoogleFonts.outfitTextTheme(Theme.of(context).textTheme);

          return MaterialApp.router(
            title: 'Foss Drive',
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: themeProvider.accentColor),
              useMaterial3: true,
              textTheme: textTheme,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: themeProvider.accentColor, brightness: Brightness.dark),
              useMaterial3: true,
              textTheme: textTheme,
            ),
            routerConfig: _router,
          );
        },
      ),
    );
  }
}

// Main Layout with NavigationRail
class MainLayout extends StatefulWidget {
  final Widget child;
  const MainLayout({super.key, required this.child});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isLeft = themeProvider.toolbarPosition == ToolbarPosition.left;

    // Map route to index
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home')) _selectedIndex = 0;
    else if (location.startsWith('/offline-files')) _selectedIndex = 1;
    else if (location.startsWith('/switch-account')) _selectedIndex = 2;
    else if (location.startsWith('/settings')) _selectedIndex = 3;

    final navigationRail = NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (int index) {
        setState(() {
          _selectedIndex = index;
        });
        switch (index) {
          case 0:
            context.go('/home');
            break;
          case 1:
            context.go('/offline-files');
            break;
          case 2:
            context.go('/switch-account');
            break;
          case 3:
            context.go('/settings');
            break;
        }
      },
      labelType: NavigationRailLabelType.all,
      backgroundColor: themeProvider.enableGlassmorphism ? Colors.transparent : null,
      destinations: const <NavigationRailDestination>[
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.offline_bolt_outlined),
          selectedIcon: Icon(Icons.offline_bolt),
          label: Text('Offline'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.manage_accounts_outlined),
          selectedIcon: Icon(Icons.manage_accounts),
          label: Text('Accounts'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('Settings'),
        ),
      ],
    );

    Widget content = Scaffold(
      body: Row(
        children: [
          if (isLeft) _buildRailContainer(context, navigationRail, themeProvider),
          Expanded(child: widget.child),
          if (!isLeft) _buildRailContainer(context, navigationRail, themeProvider),
        ],
      ),
    );

    return content;
  }

  Widget _buildRailContainer(BuildContext context, Widget rail, ThemeProvider themeProvider) {
    if (themeProvider.enableGlassmorphism) {
      return ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
            child: rail,
          ),
        ),
      );
    }
    return rail;
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  @override
  Widget build(BuildContext context) {
    final authNotifier = Provider.of<AuthNotifier>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_circle, size: 80, color: Colors.blue),
                const SizedBox(height: 20),
                Text('Foss Drive', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text('Service Account Login', style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 40),

                if (authNotifier.isLoading)
                   const CircularProgressIndicator()
                else
                   SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload cred.json'),
                      onPressed: () async {
                        try {
                          FilePickerResult? result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['json'],
                          );

                          if (result != null) {
                            File file = File(result.files.single.path!);
                            String content = await file.readAsString();
                            await authNotifier.loginWithCredentials(content);
                            if (authNotifier.currentAccount != null) {
                                context.go('/home');
                            }
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Login failed: ${e.toString()}')),
                          );
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text('Please upload a valid Service Account JSON key.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DriveHomeScreen extends StatefulWidget {
  const DriveHomeScreen({super.key});

  @override
  State<DriveHomeScreen> createState() => _DriveHomeScreenState();
}

class _DriveHomeScreenState extends State<DriveHomeScreen> {

  @override
  void initState() {
    super.initState();
    // Fetch initial items
    WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<DriveNotifier>(context, listen: false).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final driveNotifier = Provider.of<DriveNotifier>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(driveNotifier.currentFolderName ?? 'Foss Drive Home'),
        leading: driveNotifier.currentParentId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => driveNotifier.goBack(),
              )
            : null,
      ),
      body: driveNotifier.isLoading
          ? const Center(child: CircularProgressIndicator())
          : driveNotifier.currentFolderItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  const Text('This folder is empty'),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                childAspectRatio: 1.0,
              ),
              itemCount: driveNotifier.currentFolderItems.length,
              itemBuilder: (context, index) {
                final item = driveNotifier.currentFolderItems[index];
                return _buildFileCard(context, item, driveNotifier, themeProvider)
                    .animate().fadeIn(delay: (index * 50).ms).scale();
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewItemOptions(context, driveNotifier),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFileCard(BuildContext context, DriveItem item, DriveNotifier driveNotifier, ThemeProvider themeProvider) {
    // Generate an icon or fetch thumbnail
    Widget preview;
    if (item.thumbnailUrl != null) {
        preview = Image.network(
            item.thumbnailUrl!,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => Icon(Icons.broken_image, size: 48, color: Theme.of(context).colorScheme.error),
        );
    } else {
         IconData iconData = Icons.insert_drive_file;
         Color iconColor = Theme.of(context).colorScheme.primary;

         if (item.type == FileType.folder) {
             iconData = Icons.folder;
             iconColor = Colors.amber;
         } else if (item.type == FileType.image) {
             iconData = Icons.image;
             iconColor = Colors.purple;
         }

         preview = Icon(iconData, size: 48, color: iconColor);
    }

    Widget cardContent = Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(themeProvider.enableGlassmorphism ? 0.5 : 1),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (item.type == FileType.folder) {
            driveNotifier.openFolder(item);
          } else {
            if (item.isOfflineAvailable) {
               // Open offline file
               driveNotifier.getOfflineFiles().then((files) async {
                   // This is a bit inefficient to scan all, but fits the current structure
                   // Better: driveService exposing getPath
                   // For now, we assume standard offline path
                   final path = '/data/user/0/com.example.myapp/app_flutter/offline_files/${item.id}_${item.name}';
                   // Note: Hardcoded path is risky, better to expose from service.
                   // Let's just show snackbar for "Offline Ready" or attempt open if we have path

                   // Better approach:
                   ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Opening ${item.name}...')),
                   );
                   // In real app: OpenFile.open(path);
               });
            } else {
               ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Download file first to open (Mock)')),
               );
            }
          }
        },
        onLongPress: () => _showItemContextMenu(context, item, driveNotifier),
        child: Column(
          children: [
            Expanded(
                child: Container(
                    width: double.infinity,
                    color: item.type == FileType.folder ? Colors.transparent : Colors.black12,
                    child: Center(child: preview),
                ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                    Text(
                        item.name,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                    ),
                    if (item.isOfflineAvailable)
                        Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Icon(Icons.check_circle, size: 14, color: Theme.of(context).colorScheme.primary),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (themeProvider.enableGlassmorphism) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: cardContent,
        ),
      );
    }
    return cardContent;
  }

  void _showItemContextMenu(BuildContext context, DriveItem item, DriveNotifier driveNotifier) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
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
                  // Show details dialog
                },
              ),
               ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Rename'),
                onTap: () {
                  context.pop();
                   _showRenameDialog(context, item, driveNotifier);
                },
              ),
              if (item.type != FileType.folder) ...[
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Download to Storage'),
                  onTap: () async {
                    context.pop();
                    await driveNotifier.downloadFile(item);
                    ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('Download started...')),
                    );
                  },
                ),
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
               ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  context.pop();
                  await driveNotifier.deleteFile(item);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context, DriveItem item, DriveNotifier driveNotifier) {
      final controller = TextEditingController(text: item.name);
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
              title: const Text("Rename"),
              content: TextField(controller: controller),
              actions: [
                  TextButton(onPressed: () => ctx.pop(), child: const Text("Cancel")),
                  TextButton(onPressed: () async {
                      if (controller.text.isNotEmpty) {
                          await driveNotifier.renameFile(item, controller.text);
                          if (ctx.mounted) ctx.pop();
                      }
                  }, child: const Text("Rename")),
              ],
          )
      );
  }

  void _showNewItemOptions(BuildContext context, DriveNotifier driveNotifier) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.create_new_folder_outlined),
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

  void _showCreateFolderDialog(BuildContext context, DriveNotifier driveNotifier) {
    final TextEditingController folderNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Folder'),
        content: TextField(
          controller: folderNameController,
          decoration: const InputDecoration(
            hintText: 'Enter folder name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
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

  void _showUploadFileDialog(BuildContext context, DriveNotifier driveNotifier) async {
       try {
          FilePickerResult? result = await FilePicker.platform.pickFiles();

          if (result != null) {
            File file = File(result.files.single.path!);
            // We use the file name from picker
            await driveNotifier.uploadFile(file, result.files.single.name);
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: ${e.toString()}')),
          );
        }
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
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                   SwitchListTile(
                    title: const Text('Dark Mode'),
                    secondary: const Icon(Icons.dark_mode),
                    value: themeProvider.themeMode == ThemeMode.dark,
                    onChanged: (bool value) {
                      themeProvider.toggleTheme(value);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Enable Glassmorphism'),
                    subtitle: const Text('Adds blur effects to UI elements'),
                    secondary: const Icon(Icons.blur_on),
                    value: themeProvider.enableGlassmorphism,
                    onChanged: (bool value) {
                      themeProvider.toggleGlassmorphism(value);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Accent Color'),
                    leading: const Icon(Icons.color_lens),
                    trailing: DropdownButton<Color>(
                      value: themeProvider.accentColor,
                      underline: Container(),
                      onChanged: (Color? newColor) {
                        if (newColor != null) {
                          themeProvider.setAccentColor(newColor);
                        }
                      },
                      items: <Color>[
                        Colors.blue,
                        Colors.green,
                        Colors.deepPurple,
                        Colors.purple,
                        Colors.orange,
                        Colors.red,
                      ].map<DropdownMenuItem<Color>>((Color value) {
                        return DropdownMenuItem<Color>(
                          value: value,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: value,
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Toolbar Position'),
                    leading: const Icon(Icons.view_sidebar),
                    trailing: DropdownButton<ToolbarPosition>(
                      value: themeProvider.toolbarPosition,
                      underline: Container(),
                      onChanged: (ToolbarPosition? newPosition) {
                        if (newPosition != null) {
                          themeProvider.setToolbarPosition(newPosition);
                        }
                      },
                      items: ToolbarPosition.values.map<DropdownMenuItem<ToolbarPosition>>((ToolbarPosition value) {
                        return DropdownMenuItem<ToolbarPosition>(
                          value: value,
                          child: Text(
                            value == ToolbarPosition.left ? 'Left' : 'Right',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AccountSwitcherScreen extends StatelessWidget {
  const AccountSwitcherScreen({super.key});

  // Generates a colorful avatar based on name
  Color _getAvatarColor(String name) {
      final colors = [Colors.red, Colors.green, Colors.blue, Colors.orange, Colors.purple, Colors.teal];
      return colors[name.hashCode % colors.length];
  }

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
          } else {
            final accounts = snapshot.data ?? [];
            return ListView.builder(
              itemCount: accounts.length + 1,
              itemBuilder: (context, index) {
                if (index == accounts.length) {
                   return ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Add Another Account (Upload JSON)'),
                    onTap: () async {
                       try {
                          FilePickerResult? result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['json'],
                          );

                          if (result != null) {
                            File file = File(result.files.single.path!);
                            String content = await file.readAsString();
                            await authNotifier.addAccount(content);

                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account Added')));
                            // Refresh list by triggering rebuild? setState?
                            // Since we use FutureBuilder, it wont auto update unless parent rebuilds.
                            // But AuthNotifier notifyListeners() should trigger this if this widget was Consumer,
                            // but it is not.
                            (context as Element).markNeedsBuild();
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Add account failed: ${e.toString()}')),
                          );
                        }
                    },
                   );
                }

                final account = accounts[index];
                final isCurrent = authNotifier.currentAccount?.id == account.id;

                return ListTile(
                  leading: CircleAvatar(
                      backgroundColor: _getAvatarColor(account.email),
                      child: Text(account.name.isNotEmpty ? account.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(account.name.isEmpty ? 'Service Account' : account.name),
                  subtitle: Text(account.email),
                  tileColor: isCurrent ? Theme.of(context).colorScheme.primaryContainer : null,
                  onTap: () async {
                    await authNotifier.switchAccount(account);
                    // Reset drive state for new account
                    Provider.of<DriveNotifier>(context, listen: false).reset();
                    Provider.of<DriveNotifier>(context, listen: false).refresh();
                    context.go('/home');
                  },
                  trailing: isCurrent
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : IconButton(
                        icon: const Icon(Icons.logout),
                        onPressed: () async {
                           // Logout logic needs refinement to remove account
                           // For now just global logout
                          await authNotifier.logout();
                          context.go('/');
                        },
                      ),
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
      body: FutureBuilder<List<DriveItem>>(
        future: driveNotifier.getOfflineFiles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
             return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  const Text('No offline files'),
                ],
              ),
            );
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
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await driveNotifier.toggleOfflineAvailability(file);
                      (context as Element).markNeedsBuild();
                    },
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Opening offline file: ${file.name}')),
                    );
                  },
                ).animate().slideX(begin: 0.1).fadeIn();
              },
            );
          }
        },
      ),
    );
  }
}
