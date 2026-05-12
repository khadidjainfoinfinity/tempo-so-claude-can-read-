import '../services/locale_service.dart';

/// Static string lookup. Reads the current locale from [LocaleService].
/// The whole app rebuilds via ValueListenableBuilder of Locale in main.dart,
/// so all S.xxx calls always return the right language.
class S {
  static String get _l => LocaleService.instance.languageCode;

  static String _t(String en, String fr, String ar) =>
      _l == 'fr' ? fr : _l == 'ar' ? ar : en;

  // ── Language display names (shown in their own language) ────────
  static const langEn = 'English';
  static const langFr = 'Français';
  static const langAr = 'العربية';

  static String displayName(String code) {
    switch (code) {
      case 'fr': return langFr;
      case 'ar': return langAr;
      default:   return langEn;
    }
  }

  // ── Navigation ──────────────────────────────────────────────────
  static String get navHome    => _t('Home',    'Accueil',    'الرئيسية');
  static String get navCart    => _t('Cart',    'Panier',     'السلة');
  static String get navSearch  => _t('Search',  'Recherche',  'البحث');
  static String get navOrders  => _t('Orders',  'Commandes',  'الطلبات');
  static String get navProfile => _t('Profile', 'Profil',     'الملف');

  // ── Greetings ────────────────────────────────────────────────────
  static String get goodMorning   => _t('Good morning',   'Bonjour',        'صباح الخير');
  static String get goodAfternoon => _t('Good afternoon', 'Bon après-midi', 'مساء النور');
  static String get goodEvening   => _t('Good evening',   'Bonsoir',        'مساء الخير');

  // ── Common ───────────────────────────────────────────────────────
  static String get save      => _t('Save',   'Enregistrer', 'حفظ');
  static String get cancel    => _t('Cancel', 'Annuler',     'إلغاء');
  static String get retry     => _t('Retry',  'Réessayer',   'إعادة المحاولة');
  static String get total     => _t('Total',  'Total',       'المجموع');
  static String get loading   => _t('Loading…', 'Chargement…', 'جارٍ التحميل…');
  static String get error     => _t('Something went wrong', 'Quelque chose a mal tourné', 'حدث خطأ ما');
  static String get noInternet => _t('Connection error', 'Erreur de connexion', 'خطأ في الاتصال');

  // ── Validation ───────────────────────────────────────────────────
  static String get required        => _t('Required', 'Requis', 'مطلوب');
  static String get min6Chars       => _t('Min. 6 characters', 'Min. 6 caractères', '6 أحرف على الأقل');
  static String get passwordMismatch => _t('Passwords do not match', 'Les mots de passe ne correspondent pas', 'كلمات المرور غير متطابقة');

  // ── Home ─────────────────────────────────────────────────────────
  static String get searchHint        => _t('Search by product/brand…', 'Rechercher par produit/marque…', 'البحث بالمنتج/الماركة…');
  static String get recommendedForYou => _t('Recommended for You', 'Recommandé pour vous', 'موصى به لك');
  static String get allProducts       => _t('All Products', 'Tous les produits', 'جميع المنتجات');
  static String get shopNow           => _t('Shop now →', 'Acheter →', 'تسوق الآن ←');
  static String get items             => _t('items', 'articles', 'منتج');
  static String get noProductsFound   => _t('No products found', 'Aucun produit trouvé', 'لم يتم العثور على منتجات');
  static String get welcome           => _t('Welcome!', 'Bienvenue!', 'أهلاً بك!');
  static String get go                => _t('Go', 'OK', 'بحث');

  // ── Category names (internal key → display) ───────────────────────
  static String categoryName(String key) {
    final map = {
      'All':       _t('All',              'Tous',               'الكل'),
      'FruitsVeg': _t('Fruits & Veg',    'Fruits & Légumes',   'الفواكه والخضروات'),
      'Bakery':    _t('Bakery',          'Boulangerie',        'المخبوزات'),
      'Meat':      _t('Meat & Fish',     'Viandes & Poissons', 'اللحوم والأسماك'),
      'Dairy':     _t('Dairy',          'Produits laitiers',  'منتجات الألبان'),
      'Beverages': _t('Beverages',       'Boissons',           'المشروبات'),
      'Groceries': _t('Groceries',       'Épicerie',           'البقالة'),
      'Frozen':    _t('Frozen',          'Surgelés',           'مجمدات'),
      'Beauty':    _t('Hygiene & Beauty','Hygiène & Beauté',   'الصحة والجمال'),
      'Other':     _t('Other',           'Autre',              'أخرى'),
    };
    return map[key] ?? key;
  }

  // ── Deals ─────────────────────────────────────────────────────────
  static String get freshGroceries => _t('Fresh Groceries', 'Épicerie fraîche', 'بقالة طازجة');
  static String get upTo20Off      => _t('Up to 20% off',  'Jusqu\'à -20%',    'خصم 20%');
  static String get electronics    => _t('Electronics',     'Électronique',     'الإلكترونيات');
  static String get newArrivals    => _t('New arrivals',    'Nouveautés',       'وصل حديثاً');
  static String get dairyMore      => _t('Dairy & More',   'Produits laitiers', 'ألبان وأكثر');
  static String get buy2Get1       => _t('Buy 2 get 1',    'Achetez 2 = 3',    'اشتر 2 واحصل على 1');

  // ── Cart ──────────────────────────────────────────────────────────
  static String get myCart          => _t('My Cart',              'Mon Panier',         'سلتي');
  static String get clearAll        => _t('Clear all',            'Tout effacer',       'مسح الكل');
  static String get cartEmpty       => _t('Your cart is empty',   'Votre panier est vide', 'سلتك فارغة');
  static String get proceedCheckout => _t('Proceed to Checkout',  'Passer à la caisse', 'الانتقال للدفع');

  // ── Checkout ──────────────────────────────────────────────────────
  static String get checkout        => _t('Checkout',         'Paiement',            'الدفع');
  static String get orderSummary    => _t('Order Summary',    'Résumé de commande',  'ملخص الطلب');
  static String get customerInfo    => _t('Customer Info',    'Infos client',        'معلومات العميل');
  static String get paymentMethod   => _t('Payment Method',   'Mode de paiement',   'طريقة الدفع');
  static String get confirmOrder    => _t('Confirm Order',    'Confirmer',           'تأكيد الطلب');
  static String get orderPlaced     => _t('Order Placed!',    'Commande passée!',   'تم تقديم الطلب!');
  static String get orderPlacedMsg  => _t(
    'Your order has been placed successfully.\nWe\'ll notify you when it\'s on the way.',
    'Votre commande a été passée avec succès.\nNous vous notifierons dès qu\'elle est en route.',
    'تم تقديم طلبك بنجاح.\nسنخطرك عندما يكون في الطريق.',
  );
  static String get backToCart      => _t('Back to Cart',       'Retour au panier',    'العودة للسلة');
  static String get cash            => _t('Cash',               'Espèces',             'نقداً');

  // ── Search ────────────────────────────────────────────────────────
  static String get sortBy          => _t('Sort by',              'Trier par',            'ترتيب حسب');
  static String get sortName        => _t('Name (A → Z)',         'Nom (A → Z)',          'الاسم (أ → ي)');
  static String get sortPriceAsc    => _t('Price: Low → High',    'Prix: Bas → Élevé',   'السعر: الأقل أولاً');
  static String get sortPriceDesc   => _t('Price: High → Low',   'Prix: Élevé → Bas',   'السعر: الأعلى أولاً');
  static String get noResults       => _t('No results',           'Aucun résultat',       'لا نتائج');
  static String get tryDifferent    => _t('Try a different search or category', 'Essayez une autre recherche ou catégorie', 'جرب بحثاً أو فئة مختلفة');

  static String productsFound(int n) => _t(
    '$n product${n != 1 ? 's' : ''} found',
    '$n produit${n != 1 ? 's' : ''} trouvé${n != 1 ? 's' : ''}',
    'تم العثور على $n منتج',
  );

  // ── Purchase History ──────────────────────────────────────────────
  static String get purchaseHistory => _t('Purchase History', 'Historique des achats', 'سجل المشتريات');
  static String get selectAll       => _t('Select All',        'Tout sélectionner',    'تحديد الكل');
  static String get deselectAll     => _t('Deselect All',      'Tout désélectionner',  'إلغاء التحديد');
  static String get noOrders        => _t('No orders yet',     'Aucune commande',       'لا توجد طلبات');
  static String get noOrdersMsg     => _t(
    'Your purchase history will appear here',
    'Votre historique d\'achats apparaîtra ici',
    'سيظهر سجل مشترياتك هنا',
  );
  static String get downloadPdf     => _t('Download',          'Télécharger',          'تحميل');
  static String get generatingPdf   => _t('Generating PDF…',   'Génération PDF…',      'جارٍ إنشاء PDF…');
  static String get ordersLabel     => _t('Orders',            'Commandes',            'الطلبات');
  static String get doneLabel       => _t('Done',              'Terminé',              'منتهي');
  static String get spentLabel      => _t('Spent',             'Dépensé',              'المنفق');
  static String get itemsLabel      => _t('Items',             'Articles',             'العناصر');

  static String ordersCount(int n) =>
      '$n ${n != 1 ? _t('orders', 'commandes', 'طلبات') : _t('order', 'commande', 'طلب')}';
  static String selectedCount(int n) =>
      '$n ${_t('selected', 'sélectionné${n > 1 ? 's' : ''}', 'محدد')}';
  static String downloadCount(int n) => _t(
    'Download $n receipt${n != 1 ? 's' : ''} as PDF',
    'Télécharger $n reçu${n != 1 ? 's' : ''} en PDF',
    'تنزيل $n إيصال كـ PDF',
  );
  static String get selectToDownload => _t(
    'Select orders to download',
    'Sélectionner des commandes',
    'اختر طلبات للتنزيل',
  );

  // ── Status labels ─────────────────────────────────────────────────
  static String statusLabel(String key) {
    final map = {
      'completed': _t('Completed', 'Complété',   'مكتمل'),
      'pending':   _t('Pending',   'En attente', 'قيد الانتظار'),
      'cancelled': _t('Cancelled', 'Annulé',     'ملغي'),
      'refunded':  _t('Refunded',  'Remboursé',  'مسترد'),
    };
    return map[key] ?? key;
  }

  // Filter tab labels
  static String get filterAll       => _t('All',       'Tous',       'الكل');
  static String get filterPending   => _t('Pending',   'En attente', 'انتظار');
  static String get filterCompleted => _t('Completed', 'Complété',   'مكتمل');
  static String get filterCancelled => _t('Cancelled', 'Annulé',     'ملغي');

  // ── Profile ───────────────────────────────────────────────────────
  static String get accountSettings    => _t('Account Settings',     'Paramètres du compte',       'إعدادات الحساب');
  static String get nameLabel          => _t('Name',                 'Nom',                        'الاسم');
  static String get emailLabel         => _t('Email',                'E-mail',                     'البريد الإلكتروني');
  static String get phoneLabel         => _t('Phone',                'Téléphone',                  'الهاتف');
  static String get changePassword     => _t('Change Password',      'Changer le mot de passe',    'تغيير كلمة المرور');
  static String get shoppingPrefs      => _t('Shopping Preferences', 'Préférences d\'achat',       'تفضيلات التسوق');
  static String get categoriesLabel    => _t('Categories',           'Catégories',                 'الفئات');
  static String get allergiesLabel     => _t('Allergies',            'Allergies',                  'الحساسية');
  static String get lifestyleLabel     => _t('Lifestyle',            'Mode de vie',                'نمط الحياة');
  static String get appSettings        => _t('App Settings',         'Paramètres de l\'app',       'إعدادات التطبيق');
  static String get languageLabel      => _t('Language',             'Langue',                     'اللغة');
  static String get darkMode           => _t('Dark Mode',            'Mode sombre',                'الوضع الداكن');
  static String get logOut             => _t('LOG OUT',              'SE DÉCONNECTER',             'تسجيل الخروج');
  static String get tapToSet           => _t('Tap to set',           'Appuyer pour définir',       'اضغط للتعيين');
  static String get tapToSelect        => _t('Tap to select',        'Appuyer pour sélectionner',  'اضغط للاختيار');
  static String get editName           => _t('Edit Name',            'Modifier le nom',            'تعديل الاسم');
  static String get editEmail          => _t('Edit Email',           'Modifier l\'e-mail',         'تعديل البريد');
  static String get editPhone          => _t('Edit Phone',           'Modifier le téléphone',      'تعديل الهاتف');
  static String get yourFullName       => _t('Your full name',       'Votre nom complet',          'اسمك الكامل');
  static String get yourEmail          => _t('Your email address',   'Votre adresse e-mail',       'عنوان بريدك');
  static String get yourPhone          => _t('Your phone number',    'Votre numéro de téléphone',  'رقم هاتفك');
  static String get currentPassword    => _t('Current Password',     'Mot de passe actuel',        'كلمة المرور الحالية');
  static String get newPassword        => _t('New Password',         'Nouveau mot de passe',       'كلمة المرور الجديدة');
  static String get confirmNewPassword => _t('Confirm New Password', 'Confirmer le nouveau mot de passe', 'تأكيد كلمة المرور الجديدة');
  static String get updatePassword     => _t('Update Password',      'Mettre à jour',              'تحديث كلمة المرور');
  static String get passwordUpdated    => _t('Password updated successfully!', 'Mot de passe mis à jour!', 'تم تحديث كلمة المرور!');
  static String get selectLanguage     => _t('Select Language',      'Choisir la langue',          'اختر اللغة');
  static String get profileUpdated     => _t('Profile updated',       'Profil mis à jour',          'تم تحديث الملف الشخصي');
  static String get preferencesUpdated => _t('Preferences updated',  'Préférences mises à jour',   'تم تحديث التفضيلات');
  static String get pdfSaved           => _t('PDF saved to Downloads','PDF enregistré',             'تم حفظ PDF');
  static String get pdfSaveError       => _t('Failed to save PDF',    'Échec de l\'enregistrement', 'فشل حفظ PDF');
  static String get profilePhoto       => _t('Profile Photo',        'Photo de profil',            'صورة الملف الشخصي');
  static String get camera             => _t('Camera',               'Appareil photo',             'الكاميرا');
  static String get gallery            => _t('Gallery',              'Galerie',                    'المعرض');
  static String get remove             => _t('Remove',               'Supprimer',                  'حذف');
  static String get logOutTitle        => _t('Log Out',              'Se déconnecter',             'تسجيل الخروج');
  static String get logOutMsg          => _t(
    'Are you sure you want to log out?',
    'Êtes-vous sûr de vouloir vous déconnecter?',
    'هل أنت متأكد من تسجيل الخروج؟',
  );
  static String get dangerZone         => _t('Danger Zone',           'Zone de danger',             'منطقة الخطر');
  static String get deleteAccount      => _t('Delete Account',        'Supprimer le compte',        'حذف الحساب');
  static String get deleteAccountTitle => _t('Delete Account?',       'Supprimer le compte?',       'حذف الحساب؟');
  static String get deleteAccountMsg   => _t(
    'This will permanently delete your account and all your data. This action cannot be undone.',
    'Cela supprimera définitivement votre compte et toutes vos données. Cette action est irréversible.',
    'سيتم حذف حسابك وجميع بياناتك نهائياً. لا يمكن التراجع عن هذا الإجراء.',
  );
  static String get deleteAccountBtn   => _t('Delete Permanently',    'Supprimer définitivement',   'حذف نهائياً');
  static String get accountDeleted     => _t('Account deleted successfully.', 'Compte supprimé avec succès.', 'تم حذف الحساب بنجاح.');
  static String get shoppingCatTitle   => _t('Shopping Categories',   'Catégories d\'achat',   'فئات التسوق');
  static String get allergiesTitle     => _t('Allergies & Intolerances', 'Allergies & intolérances', 'الحساسية وعدم التحمل');
  static String get lifestyleTitle     => _t('Lifestyle Preferences', 'Préférences de vie',    'تفضيلات نمط الحياة');

  // ── Cart ─────────────────────────────────────────────────────────────────
  static String cartIotTitle(String id) => _t('CART $id',     'PANIER $id',   'عربة $id');
  static String itemsConnected(int n, String ip) =>
      _t('$n ITEMS  •  $ip', '$n ARTICLES  •  $ip', '$n منتج  •  $ip');
  static String itemsInCart(int n) =>
      _t('$n ITEMS IN CART', '$n ARTICLES', '$n منتج في السلة');
  static String get disconnect        => _t('Disconnect',   'Déconnecter',    'قطع الاتصال');
  static String get disconnectTitle   => _t('Disconnect cart?', 'Déconnecter le panier ?', 'قطع اتصال العربة؟');
  static String get disconnectMsg     => _t(
    'This will disconnect your phone from the smart cart. The tablet will also be released.',
    'Cela déconnectera votre téléphone du panier intelligent. La tablette sera également libérée.',
    'سيؤدي هذا إلى قطع اتصال هاتفك بالعربة الذكية. سيتم تحرير الجهاز اللوحي أيضاً.',
  );
  static String get apply             => _t('Apply',        'Appliquer',      'تطبيق');
  static String get subtotal          => _t('Subtotal',     'Sous-total',     'المجموع الفرعي');
  static String get discount          => _t('Discount',     'Remise',         'الخصم');
  static String discountWith(String c)=> _t('Discount ($c)','Remise ($c)',    'خصم ($c)');
  static String get perUnit           => _t('/ UNIT',       '/ UNITÉ',        '/ وحدة');
  static String itemTotal(String a)   => _t('TOTAL: $a',    'TOTAL: $a',      'المجموع: $a');
  static String get promoHint         => _t('promo / discount code', 'code promo / réduction', 'رمز ترويجي / خصم');
  static String get scanCartQr        => _t('Scan Cart QR Code', 'Scanner le QR du panier', 'امسح رمز QR للعربة');
  static String get scanCartQrHint    => _t(
    'Scan the QR code on the smart cart\nto start adding products',
    'Scannez le QR du panier intelligent\npour ajouter des produits',
    'امسح رمز QR على العربة الذكية\nلبدء إضافة المنتجات',
  );
  static String get invalidPromoCode  => _t('Invalid promo code', 'Code promo invalide', 'رمز ترويجي غير صالح');

  // ── Checkout extras ───────────────────────────────────────────────────────
  static String get electronic        => _t('Electronic',   'Électronique',   'إلكتروني');
  static String get electronicNote    => _t(
    'You will choose EDAHABIA or CIB and enter your card details on the next screen.',
    'Vous choisirez EDAHABIA ou CIB et saisirez les détails de votre carte.',
    'ستختار EDAHABIA أو CIB وتدخل بيانات بطاقتك في الشاشة التالية.',
  );
  static String get enterCardDetails  => _t('Enter Card Details →', 'Détails de la carte →', 'أدخل بيانات البطاقة →');
  static String get confirmCashOrder  => _t('Confirm Cash Order', 'Confirmer (Espèces)', 'تأكيد الدفع نقداً');
  static String get pleaseLoginFirst  => _t('Please log in first', 'Veuillez vous connecter', 'يرجى تسجيل الدخول أولاً');

  // ── Favorites ─────────────────────────────────────────────────────────────
  static String get favorites         => _t('Favorites',    'Favoris',        'المفضلة');
  static String get noFavorites       => _t('No favorites yet', 'Aucun favori', 'لا توجد مفضلة');
  static String get noFavoritesHint   => _t(
    'Tap ♡ on any product to save it',
    'Appuyez sur ♡ pour sauvegarder',
    'اضغط ♡ على أي منتج لحفظه',
  );

  // ── Product Detail ────────────────────────────────────────────────────────
  static String get loginToReview     => _t('Log in to leave a review', 'Connectez-vous pour laisser un avis', 'سجّل الدخول لترك تقييم');
  static String get anonymous         => _t('Anonymous',    'Anonyme',        'مجهول');
  static String get defaultProductDesc => _t(
    'Premium quality product available in our store.',
    'Produit de qualité premium disponible dans notre boutique.',
    'منتج عالي الجودة متوفر في متجرنا.',
  );
  static String get variantsLabel     => _t('Variants',     'Variantes',      'الأشكال');
  static String optionN(int n)        => _t('Option $n',    'Option $n',      'خيار $n');
  static String get descriptionLabel  => _t('Description',  'Description',    'الوصف');
  static String get customerReviews   => _t('Customer Reviews', 'Avis clients', 'تقييمات العملاء');
  static String get leaveReview       => _t('Leave a Review', "Laisser un avis", 'اترك تقييماً');
  static String get yourNameOptional  => _t('Your name (optional)', 'Votre nom (optionnel)', 'اسمك (اختياري)');
  static String get ratingLabel       => _t('Rating:',      'Note :',         'التقييم:');
  static String get writeComment      => _t('Write your comment...', 'Écrivez votre commentaire...', 'اكتب تعليقك...');
  static String get publishReview     => _t('Publish Review', "Publier l'avis", 'نشر التقييم');
  static String get beFirstToReview   => _t('Be the first to leave a review!', 'Soyez le premier à laisser un avis !', 'كن أول من يترك تقييماً!');
  static String get noReviewsYet      => _t('No reviews yet', 'Aucun avis pour le moment', 'لا توجد تقييمات بعد');
  static String ratingCount(String avg, int n) => _t(
    '$avg  ($n review${n != 1 ? "s" : ""})', '$avg  ($n avis)', '$avg  ($n تقييم)',
  );
  static String get addToCart         => _t('Add to Cart',  'Ajouter au panier', 'أضف للسلة');
  static String get addedToCart       => _t('Added to Cart', 'Ajouté au panier', 'تمت الإضافة');
  static String get allergenDetected  => _t('Allergen Detected', 'Allergène détecté', 'تم اكتشاف مسبب حساسية');
  static String allergenContains(String a) => _t('Contains: $a', 'Contient : $a', 'يحتوي على: $a');
  static String get allergenWarningMsg => _t(
    'This product contains an allergen you declared.',
    'Ce produit contient un allergène que vous avez déclaré.',
    'هذا المنتج يحتوي على مسبب حساسية أعلنته.',
  );
  static String get healthWarningTitle => _t(
    'Not compatible with your health profile',
    'Non compatible avec votre profil santé',
    'غير متوافق مع ملفك الصحي',
  );
  static String get healthWarningMsg  => _t(
    "This product doesn't match your declared health profile.",
    'Ce produit ne correspond pas à votre profil de santé déclaré.',
    'هذا المنتج لا يتوافق مع ملفك الصحي.',
  );
  static String get submissionError   => _t('Submission error', 'Erreur lors de la soumission', 'خطأ في الإرسال');

  // ── Search extras ─────────────────────────────────────────────────────────
  static String get search            => _t('Search',         'Recherche',      'البحث');
  static String get searchSubtitle    => _t('find your favourite products', 'trouvez vos produits préférés', 'ابحث عن منتجاتك المفضلة');
  static String get healthLabel       => _t('Health',       'Santé',          'صحة');

  // ── Profile extras ────────────────────────────────────────────────────────
  static String get userLabel         => _t('User',         'Utilisateur',    'المستخدم');
  static String get failedChangePwd   => _t('Failed to change password', 'Échec du changement de mot de passe', 'فشل تغيير كلمة المرور');

  // ── Purchase History extras ───────────────────────────────────────────────
  static String get notLoggedIn       => _t('Not logged in',  'Non connecté',  'غير مسجّل الدخول');
  static String get failedLoadOrders  => _t('Failed to load orders', 'Échec du chargement', 'فشل تحميل الطلبات');
  static String get orderItemsLabel   => _t('ORDER ITEMS',   'ARTICLES',       'عناصر الطلب');
  static String get itemLabel         => _t('Item',          'Article',        'المنتج');
  static String get qtyLabel          => _t('Qty',           'Qté',            'الكمية');
  static String get unitPriceLabel    => _t('Unit Price',    'Prix unitaire',  'سعر الوحدة');
  static String get thankYouMsg       => _t('Thank you for shopping with NovaShop!', 'Merci pour votre achat chez NovaShop!', 'شكراً لتسوقك مع NovaShop!');
  static String generatedOn(String d) => _t('Generated on $d', 'Généré le $d', 'تم الإنشاء في $d');
  static String receiptOf(int n, int t) => _t('Receipt $n of $t', 'Reçu $n sur $t', 'الإيصال $n من $t');
  static String get purchaseReceipt   => _t('Purchase Receipt', "Reçu d'achat", 'إيصال الشراء');
  static String get customerLabel     => _t('Customer',  'Client',   'العميل');
  static String get statusPdfLabel    => _t('Status',    'Statut',   'الحالة');

  // ── Scanner ───────────────────────────────────────────────────────────────
  static String get connectCart       => _t('CONNECT CART',  'CONNECTER PANIER', 'ربط العربة');
  static String get wifiHint          => _t(
    'Make sure your phone is on the supermarket WiFi',
    'Assurez-vous que votre téléphone est sur le WiFi du supermarché',
    'تأكد من اتصال هاتفك بشبكة واي فاي المتجر',
  );
  static String get step1             => _t('1 — Pick a cart at the store', '1 — Prenez un panier en magasin', '1 — اختر عربة في المتجر');
  static String get step2             => _t('2 — Open camera below', "2 — Ouvrez l'appareil photo", '2 — افتح الكاميرا أدناه');
  static String get step3             => _t('3 — Scan the QR code on the tablet', '3 — Scannez le QR sur la tablette', '3 — امسح رمز QR على الجهاز');
  static String get step4             => _t('4 — Start Shopping !', '4 — Commencez à acheter !', '4 — ابدأ التسوق!');
  static String get openCamera        => _t('Open Camera',   'Ouvrir la caméra', 'فتح الكاميرا');
  static String get invalidQr         => _t(
    'Invalid QR — scan the NovaShop tablet screen',
    "QR invalide — scannez l'écran de la tablette",
    'رمز QR غير صالح — امسح شاشة الجهاز',
  );
  static String get couldNotConnect   => _t(
    'Could not connect — check WiFi & server',
    'Impossible de se connecter — vérifiez le WiFi',
    'تعذّر الاتصال — تحقق من الشبكة',
  );
  static String get linkingToCart     => _t('LINKING TO CART...', 'CONNEXION AU PANIER...', 'جارٍ ربط العربة...');
  static String connectingTo(String ip) => _t('Connecting to $ip:5004', 'Connexion à $ip:5004', 'الاتصال بـ $ip:5004');
  static String get establishingConn  => _t('Establishing connection', 'Établissement de la connexion', 'جارٍ إنشاء الاتصال');
  static String cartConnected(String id)=> _t('Cart $id connected', 'Panier $id connecté', 'العربة $id متصلة');
  static String scanningLive(String ip) => _t('$ip:5004  •  Scanning live', '$ip:5004  •  Scan en direct', '$ip:5004  •  مسح مباشر');
  static String get tabletScanHint    => _t(
    "The tablet will scan products automatically.\nThey'll appear here instantly.",
    "La tablette scanne automatiquement.\nLes produits apparaissent instantanément.",
    "ستقوم اللوحة بالمسح تلقائياً.\nستظهر المنتجات هنا فوراً.",
  );
  static String get listeningForScans => _t('Listening for scans…', 'En attente de scans…', 'في انتظار عمليات المسح…');

  // ── Payment ───────────────────────────────────────────────────────────────
  static String get cardPayment       => _t('Card Payment',  'Paiement par carte', 'الدفع بالبطاقة');
  static String get cardNumber        => _t('Card Number',   'Numéro de carte',  'رقم البطاقة');
  static String get invalidCardNumber => _t('Enter a valid 16-digit number', 'Entrez un numéro de 16 chiffres', 'أدخل رقماً صالحاً من 16 خانة');
  static String get cardholderName    => _t('Cardholder Name', 'Nom du titulaire', 'اسم حامل البطاقة');
  static String get enterFullName     => _t('Enter your full name', 'Entrez votre nom complet', 'أدخل اسمك الكامل');
  static String get expiryDate        => _t('Expiry Date',   "Date d'expiration", 'تاريخ الانتهاء');
  static String get invalid           => _t('Invalid',       'Invalide',       'غير صالح');
  static String get invalidMonth      => _t('Invalid month', 'Mois invalide',  'شهر غير صالح');
  static String get cvv               => _t('CVV / CVC',     'CVV / CVC',      'رمز CVV');
  static String get securedByChargily => _t('Secured & processed by Chargily Pay', 'Sécurisé par Chargily Pay', 'آمن ومعالَج بواسطة Chargily Pay');
  static String get cardHolder        => _t('CARD HOLDER',   'TITULAIRE',      'حامل البطاقة');
  static String get expires           => _t('EXPIRES',       'EXPIRE',         'تنتهي');
  static String get couldNotCreateOrder => _t('Could not create order', 'Impossible de créer la commande', 'تعذّر إنشاء الطلب');
  static String get couldNotGetPayLink => _t(
    'Could not get payment link. Check your Chargily API key.',
    "Impossible d'obtenir le lien de paiement.",
    'تعذّر الحصول على رابط الدفع.',
  );
  static String get redirectedToPayment => _t(
    'Redirected to payment page. Complete payment in your browser.',
    'Redirigé vers la page de paiement.',
    'تمت إعادة التوجيه لصفحة الدفع.',
  );
  static String get couldNotOpenBrowser => _t(
    'Could not open browser. Please check your device settings.',
    "Impossible d'ouvrir le navigateur.",
    'تعذّر فتح المتصفح.',
  );

  // ── Auth misc ─────────────────────────────────────────────────────────────
  static String get or                => _t('OR',            'OU',             'أو');
  static String get otpSent           => _t('OTP sent!',     'OTP envoyé !',   'تم إرسال الرمز!');
  static String get failedSendOtp     => _t('Failed to send OTP', "Échec de l'envoi", 'فشل إرسال الرمز');
  static String get otpResentSuccess  => _t('OTP resent successfully', 'OTP renvoyé avec succès', 'تمت إعادة إرسال الرمز');
  static String get failedResendOtp   => _t('Failed to resend OTP', 'Échec du renvoi', 'فشل إعادة الإرسال');
  static String get wrongOtp          => _t('Wrong OTP',     'OTP incorrect',  'رمز التحقق خاطئ');
  static String get passwordResetOk   => _t('Password reset successfully!', 'Mot de passe réinitialisé !', 'تم إعادة تعيين كلمة المرور!');
  static String get failedResetPwd    => _t('Failed to reset password', 'Échec de la réinitialisation', 'فشل إعادة تعيين كلمة المرور');
  static String get serverError       => _t('Server error',  'Erreur serveur', 'خطأ في الخادم');

  // ── Login ─────────────────────────────────────────────────────────
  static String get signInTitle    => _t('SIGN IN TO\nNOVASHOP', 'CONNEXION À\nNOVASHOP', 'تسجيل الدخول\nإلى NovaShop');
  static String get emailOrPhone   => _t('Email Or Phone',  'E-mail ou Téléphone', 'البريد أو الهاتف');
  static String get emailHint      => _t('your email here', 'votre e-mail',        'أدخل بريدك');
  static String get passwordLabel  => _t('Password',        'Mot de passe',        'كلمة المرور');
  static String get forgotPassword => _t('FORGOT PASSWORD?','MOT DE PASSE OUBLIÉ?','نسيت كلمة المرور؟');
  static String get signIn         => _t('SIGN IN',         'SE CONNECTER',        'تسجيل الدخول');
  static String get noAccount      => _t("Don't have an account?", "Pas de compte?", "ليس لديك حساب؟");
  static String get signUpLink     => _t('Sign Up', 'S\'inscrire', 'إنشاء حساب');
  static String get orContinueWith => _t('Or continue with', 'Ou continuer avec', 'أو تابع باستخدام');
  static String get continueGoogle => _t('Continue with Google', 'Continuer avec Google', 'الدخول بحساب Google');

  // ── Sign Up ───────────────────────────────────────────────────────
  static String get createAccount  => _t('CREATE YOUR\nACCOUNT', 'CRÉER VOTRE\nCOMPTE', 'إنشاء\nحسابك');
  static String get fullName       => _t('Full Name',    'Nom complet',   'الاسم الكامل');
  static String get namehint       => _t('John Doe',     'Jean Dupont',   'أحمد خالد');
  static String get emailSignup    => _t('Email',        'E-mail',        'البريد الإلكتروني');
  static String get phoneSignup    => _t('Phone Number', 'Téléphone',     'رقم الهاتف');
  static String get confirmPwd     => _t('Confirm Password', 'Confirmer le mot de passe', 'تأكيد كلمة المرور');
  static String get signUp         => _t('SIGN UP',      'S\'INSCRIRE',   'إنشاء الحساب');
  static String get haveAccount    => _t('Already have an account?', 'Déjà un compte?', 'لديك حساب بالفعل؟');
  static String get signInLink     => _t('Sign In', 'Se connecter', 'تسجيل الدخول');

  // ── Onboarding splash ─────────────────────────────────────────────
  static String get onboardTagline  => _t('We Redefine',       'Nous Redéfinissons',  'نحن نعيد تعريف');
  static String get onboardSub      => _t(
    'Start your new shopping experience\nand discover the best deals for you.',
    'Démarrez votre nouvelle expérience shopping\net découvrez les meilleures offres.',
    'ابدأ تجربة تسوق جديدة\nاكتشف أفضل العروض لك.',
  );
  static String get startNow        => _t('START NOW!',        'COMMENCER !',         'ابدأ الآن!');

  // ── Forgot Password / OTP / Reset ────────────────────────────────
  static String get forgotPasswordTitle  => _t('FORGOT\nPASSWORD?',        'MOT DE PASSE\nOUBLIÉ ?',              'نسيت\nكلمة المرور؟');
  static String get forgotPasswordSubtitle => _t(
    'No worries! Enter your email or phone\nand we\'ll send you an OTP code right away.',
    'Pas d\'inquiétude! Entrez votre e-mail ou numéro\net nous vous enverrons un code OTP immédiatement.',
    'لا داعي للقلق! أدخل بريدك أو هاتفك\nوسنرسل لك رمز التحقق فوراً.',
  );
  static String get sendOtpVia          => _t('Send OTP via',               'Envoyer l\'OTP via',                 'إرسال الرمز عبر');
  static String get viaWhatsApp         => _t('Receive code on WhatsApp',   'Recevoir le code sur WhatsApp',      'استلام الرمز على واتساب');
  static String get viaEmail            => _t('Receive code on your registered email', 'Recevoir le code sur votre e-mail enregistré', 'استلام الرمز على بريدك المسجل');
  static String get sendCode            => _t('SEND CODE',                  'ENVOYER LE CODE',                    'إرسال الرمز');
  static String get rememberPassword    => _t('Remember your password?',    'Vous vous souvenez du mot de passe?','تتذكر كلمة المرور؟');
  static String get validEmailOrPhone   => _t('Enter a valid email or Algerian phone number', 'Entrez un e-mail ou numéro algérien valide', 'أدخل بريداً أو رقماً جزائرياً صالحاً');
  static String get resetPasswordTitle  => _t('RESET\nPASSWORD',           'RÉINITIALISER\nLE MOT DE PASSE',     'إعادة تعيين\nكلمة المرور');
  static String get confirm             => _t('CONFIRM',                    'CONFIRMER',                          'تأكيد');
  static String get otpTitle            => _t('FORGOT\nPASSWORD',          'MOT DE PASSE\nOUBLIÉ',              'نسيت\nكلمة المرور');
  static String get enterCodeSentTo     => _t('Enter code sent to',         'Entrez le code envoyé à',            'أدخل الرمز المرسل إلى');
  static String get didntGetCode        => _t('Didn\'t get the code?',      'Vous n\'avez pas reçu le code ?',   'لم تستلم الرمز؟');
  static String get resend              => _t('Resend',                     'Renvoyer',                           'إعادة إرسال');
  static String get submitOtp           => _t('SUBMIT',                     'SOUMETTRE',                          'تأكيد');
  static String get whatsapp            => 'WhatsApp';

  // ── Onboarding / Category selection ──────────────────────────────
  static String get skip                => _t('Skip',      'Ignorer',    'تخطى');
  static String get continueBtn         => _t('CONTINUE',  'CONTINUER',  'متابعة');
  static String get goToHome            => _t('GO TO HOME','ACCUEIL',    'الذهاب للرئيسية');
  static String get lifestyleDietTitle  => _t(
    'Do you follow any of the\nfollowing diets?',
    'Suivez-vous l\'un de ces\nrégimes alimentaires ?',
    'هل تتبع أياً من\nهذه الأنظمة الغذائية؟',
  );
  static String get lifestyleDietSub    => _t(
    'Pick your lifestyle, we\'ll recommend\nproducts that match it perfectly.',
    'Choisissez votre style de vie, nous recommanderons\ndes produits qui correspondent parfaitement.',
    'اختر نمط حياتك، وسنوصي بمنتجات\nتناسبك تماماً.',
  );
  static String get allergiesOnboardTitle => _t(
    'Any ingredient allergies\nor intolerances?',
    'Des allergies ou intolérances\nalimentaires ?',
    'هل لديك حساسية أو عدم\nتحمل لمكونات؟',
  );
  static String get shoppingCatOnboardTitle => _t(
    'What do you shop mostly?',
    'Qu\'est-ce que vous achetez le plus ?',
    'ماذا تتسوق في الغالب؟',
  );
  static String get shoppingCatOnboardSub => _t(
    'Pick your most frequent shopping categories\nso we can personalise your home feed.',
    'Choisissez vos catégories les plus fréquentes\npour personnaliser votre fil d\'accueil.',
    'اختر فئات تسوقك الأكثر تكراراً\nلتخصيص صفحتك الرئيسية.',
  );
  static String allSetTitle(String name) => _t(
    'You\'re all set, $name!',
    'C\'est parti, $name !',
    'أنت جاهز، $name!',
  );
  static String get allSetSubtitle      => _t(
    'Your profile is ready. We\'ll use your\npreferences to personalise everything.',
    'Votre profil est prêt. Nous utiliserons vos\npréférences pour tout personnaliser.',
    'ملفك الشخصي جاهز. سنستخدم تفضيلاتك\nلتخصيص كل شيء لك.',
  );

  // ── Preference option labels ──────────────────────────────────────
  static String lifestyleOption(String key) {
    final map = {
      'Vegan':        _t('Vegan',         'Végétalien',       'نباتي صارم'),
      'Vegetarian':   _t('Vegetarian',    'Végétarien',       'نباتي'),
      'Organic':      _t('Organic',       'Bio',              'عضوي'),
      'Halal':        _t('Halal',         'Halal',            'حلال'),
      'Kosher':       _t('Kosher',        'Casher',           'كوشير'),
      'Keto':         _t('Keto',          'Kéto',             'كيتو'),
      'Low Sugar':    _t('Low Sugar',     'Faible en sucre',  'قليل السكر'),
      'Low Sodium':   _t('Low Sodium',    'Faible en sodium', 'قليل الصوديوم'),
      'High Protein': _t('High Protein',  'Riche en protéines', 'غني بالبروتين'),
      'Gluten-Free':  _t('Gluten-Free',   'Sans gluten',      'خالٍ من الغلوتين'),
    };
    return map[key] ?? key;
  }

  static String allergyOption(String key) {
    final map = {
      'Gluten':    _t('Gluten',    'Gluten',      'غلوتين'),
      'Lactose':   _t('Lactose',   'Lactose',     'لاكتوز'),
      'Nuts':      _t('Nuts',      'Noix',        'مكسرات'),
      'Eggs':      _t('Eggs',      'Œufs',        'بيض'),
      'Soy':       _t('Soy',       'Soja',        'صويا'),
      'Fish':      _t('Fish',      'Poisson',     'سمك'),
      'Shellfish': _t('Shellfish', 'Crustacés',   'محار'),
      'Sesame':    _t('Sesame',    'Sésame',      'سمسم'),
      'Peanuts':   _t('Peanuts',   'Cacahuètes',  'فول سوداني'),
      'Sulfites':  _t('Sulfites',  'Sulfites',    'كبريتيت'),
    };
    return map[key] ?? key;
  }
}
