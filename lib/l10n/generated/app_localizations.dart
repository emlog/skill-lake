import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Skill Lake'**
  String get appTitle;

  /// No description provided for @menuSkill.
  ///
  /// In en, this message translates to:
  /// **'Skill'**
  String get menuSkill;

  /// No description provided for @menuAgent.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get menuAgent;

  /// No description provided for @menuStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get menuStore;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @author.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get author;

  /// No description provided for @homepage.
  ///
  /// In en, this message translates to:
  /// **'Homepage'**
  String get homepage;

  /// No description provided for @noEnabledAgentHint.
  ///
  /// In en, this message translates to:
  /// **'No enabled agent, please enable at least one in 「Agent Management」.'**
  String get noEnabledAgentHint;

  /// No description provided for @addCustomAgent.
  ///
  /// In en, this message translates to:
  /// **'Add Custom Agent'**
  String get addCustomAgent;

  /// No description provided for @editCustomAgent.
  ///
  /// In en, this message translates to:
  /// **'Edit Custom Agent'**
  String get editCustomAgent;

  /// No description provided for @deleteCustomAgent.
  ///
  /// In en, this message translates to:
  /// **'Delete Custom Agent'**
  String get deleteCustomAgent;

  /// No description provided for @agentName.
  ///
  /// In en, this message translates to:
  /// **'Agent Name'**
  String get agentName;

  /// No description provided for @skillsDirectory.
  ///
  /// In en, this message translates to:
  /// **'Skills Directory'**
  String get skillsDirectory;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @defaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultLabel;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @setDefaultAgent.
  ///
  /// In en, this message translates to:
  /// **'Set as Default Agent'**
  String get setDefaultAgent;

  /// No description provided for @currentDefaultAgent.
  ///
  /// In en, this message translates to:
  /// **'Current Default Agent'**
  String get currentDefaultAgent;

  /// No description provided for @syncFromDefault.
  ///
  /// In en, this message translates to:
  /// **'Sync from Default'**
  String get syncFromDefault;

  /// No description provided for @syncAllTo.
  ///
  /// In en, this message translates to:
  /// **'Sync All to...'**
  String get syncAllTo;

  /// No description provided for @syncTo.
  ///
  /// In en, this message translates to:
  /// **'Sync to...'**
  String get syncTo;

  /// No description provided for @selectTargetAgent.
  ///
  /// In en, this message translates to:
  /// **'Select target Agent to sync to'**
  String get selectTargetAgent;

  /// No description provided for @uploadInstall.
  ///
  /// In en, this message translates to:
  /// **'Upload Install'**
  String get uploadInstall;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @noInstalledSkill.
  ///
  /// In en, this message translates to:
  /// **'No installed skills'**
  String get noInstalledSkill;

  /// No description provided for @totalCount.
  ///
  /// In en, this message translates to:
  /// **'Total {count}'**
  String totalCount(int count);

  /// No description provided for @deleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete All'**
  String get deleteAll;

  /// No description provided for @confirmDeleteAll.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete All'**
  String get confirmDeleteAll;

  /// No description provided for @confirmDeleteAllContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete all Skills for this Agent?\nThis action cannot be undone.'**
  String get confirmDeleteAllContent;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get confirmDelete;

  /// No description provided for @confirmDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {name}?\nThis action cannot be undone.'**
  String confirmDeleteContent(String name);

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @path.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get path;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Network request failed: {error}'**
  String networkError(String error);

  /// No description provided for @noMatchSkill.
  ///
  /// In en, this message translates to:
  /// **'No matching skills found'**
  String get noMatchSkill;

  /// No description provided for @installing.
  ///
  /// In en, this message translates to:
  /// **'Installing...'**
  String get installing;

  /// No description provided for @install.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get install;

  /// No description provided for @refreshCache.
  ///
  /// In en, this message translates to:
  /// **'Refresh Cache'**
  String get refreshCache;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Semantic search, e.g.: SKILL for front-end development'**
  String get searchHint;

  /// No description provided for @skillsmpSettings.
  ///
  /// In en, this message translates to:
  /// **'Skillsmp Settings'**
  String get skillsmpSettings;

  /// No description provided for @apiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Setting your own API Key can get more search quota.'**
  String get apiKeyHint;

  /// No description provided for @getApiKey.
  ///
  /// In en, this message translates to:
  /// **'Get API Key: '**
  String get getApiKey;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
