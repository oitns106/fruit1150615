import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';           //請同學自行產生
import 'package:google_sign_in/google_sign_in.dart';

class Fruit {
  final String id;
  final String name;
  final String description;
  final String category;
  final int price;
  int quantity;

  Fruit({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    this.quantity=1,
  });
}

class CartProvider with ChangeNotifier {
  final List<Fruit> _cartItems=[];
  final List<String> _orderHistory=[];
  List<Fruit> get cartItems=>_cartItems;
  List<String> get orderHistory => _orderHistory;

  int get totalPrice {
    int total=0;
    for (var item in _cartItems) {
      total += item.price * item.quantity;
    }
    return total;
  }

  addToCart(Fruit fruit) {
    int index=_cartItems.indexWhere((item)=>item.id==fruit.id);
    if (index>=0) {
      _cartItems[index].quantity++;
    }
    else {
      _cartItems.add(Fruit(
        id: fruit.id,
        name: fruit.name,
        description: fruit.description,
        category: fruit.category,
        price: fruit.price,
        quantity: 1,
      ));
    }
    notifyListeners();
  }

  updateQuantity(String id, int amount) {
    int index=_cartItems.indexWhere((item)=>item.id==id);
    if (index>=0) {
      _cartItems[index].quantity+=amount;
      if (_cartItems[index].quantity<=0) {
        _cartItems.removeAt(index);
      }
    }
    notifyListeners();
  }

  checkOut() {
    if (_cartItems.isEmpty) return;
    String orderSummary="訂單日期: ${DateTime.now().toString().substring(0,16)}\n";
    for (var item in _cartItems) {
      orderSummary += "- ${item.name} x${item.quantity} (\$${item.price*item.quantity})\n";
    }
    orderSummary += "總金額: \$$totalPrice";

    _orderHistory.insert(0, orderSummary);
    _cartItems.clear();
    notifyListeners();
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {

  final emailController=TextEditingController();
  final passwordController=TextEditingController();
  final auth=FirebaseAuth.instance;

  void login() async {
    try {
      await auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>MainNavigation()));
    }
    catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('錯誤: $e')));
    }
  }

  void register() async {
    try {
      await auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('註冊成功, 請直接登入!')));
    }
    catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('錯誤: $e')));
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser=await GoogleSignIn().signIn();
      if (googleUser==null) return;

      final GoogleSignInAuthentication googleAuth=await googleUser.authentication;

      final AuthCredential credential=GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await auth.signInWithCredential(credential);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>MainNavigation()));
    }
    catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('登入失敗: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('我的水果店 - 登入頁'),),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: '電子郵件'),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: '密碼'),
              obscureText: true,
            ),
            SizedBox(height: 20,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: login, child: Text('登入'),),
                ElevatedButton(onPressed: register, child: Text('註冊'),),
              ],
            ),
            SizedBox(height: 15,),
            Divider(),
            SizedBox(height: 15,),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: OutlinedButton.icon(
                onPressed: signInWithGoogle,
                icon: Icon(Icons.g_mobiledata, size: 30, color: Colors.red,),
                label: Text('Google登入'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final GlobalKey<NavigatorState> navigatorKey=GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin=FlutterLocalNotificationsPlugin();
const AndroidNotificationChannel channel=AndroidNotificationChannel(
  'high_importance_channel',          //與AndroidManifest.xml中所定義的channel id一致
  '促銷通知',
  description: '優惠訊息',
  importance: Importance.max,
  playSound: true,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging messaging=FirebaseMessaging.instance;

  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  await flutterLocalNotificationsPlugin.
  resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

  const AndroidInitializationSettings initializationSettingsAndroid=AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings=InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(
      ChangeNotifierProvider(
        create: (context)=>CartProvider(),
        child: const MyApp()
      ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification=message.notification;
      AndroidNotification? android=message.notification?.android;

      if (notification!=null && android!=null) {
        flutterLocalNotificationsPlugin.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
            ),
          ),
        );

        if (navigatorKey.currentContext!=null) {
          showDialog(
            context: navigatorKey.currentContext!,
            builder: (context)=>AlertDialog(
              title: Text(notification.title??'最新促銷'),
              content: Text(notification.body??''),
              actions: [
                TextButton(
                  onPressed: ()=>Navigator.pop(context),
                  child: Text('取消', style: TextStyle(color: Colors.grey),),
                ),
                TextButton(
                  onPressed: () {
                     Navigator.pop(context);
                     String fruitName=message.data['targetFruit']??'大湖草莓';
                     navigatorKey.currentState?.push(MaterialPageRoute(builder: (context)=>FruitDetailPage(fruitName: fruitName)));
                  },
                  child: Text('去看看', style: TextStyle(color: Colors.green,
                                                        fontWeight: FontWeight.bold),),
                ),
              ],
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: '我的水果店',
      theme: ThemeData(primarySwatch: Colors.green,),
      home: AuthPage(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {

  int selectedIndex=0;

  final List<Widget> pages=[
    FruitListPage(),
    CartPage(),
    HistoryPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          setState(() {
            selectedIndex=index;
          });
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.store), label:'賣場'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label:'購物車'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label:'購買紀錄'),
        ],
      ),
    );
  }
}

class FruitListPage extends StatefulWidget {
  const FruitListPage({super.key});

  @override
  State<FruitListPage> createState() => _FruitListPageState();
}

class _FruitListPageState extends State<FruitListPage> {

  Future<void> importDataToFirestore(BuildContext context) async {
    final CollectionReference fruitCollection=FirebaseFirestore.instance.collection('fruits1');
    List<Map<String, dynamic>> fruitData=[
      { "category": "進口水果", "name": "富士蘋果", "price": 45, "description": "來自日本青森，果肉緊實、甜美多汁。" },
      { "category": "在地瓜果", "name": "黑珍珠蓮霧", "price": 60, "description": "屏東在地特產，果色深紅、清脆甜爽。" },
      { "category": "在地瓜果", "name": "巨峰葡萄", "price": 120, "description": "果粒飽滿，果肉Ｑ彈且帶有濃郁果香。" },
      { "category": "進口水果", "name": "紐西蘭奇異果", "price": 25, "description": "富含維他命C，酸甜適中，健康滿分。" },
      { "category": "在地瓜果", "name": "金鑽鳳梨", "price": 80, "description": "台灣在地改良，果肉細緻不咬舌、甜度高。" },
      { "category": "在地瓜果", "name": "燕巢芭樂", "price": 35, "description": "口感香脆，沾點梅子粉風味更佳。" }, { "category": "進口水果", "name": "美國華盛頓櫻桃", "price": 250, "description": "顏色深紅如寶石，飽滿多汁，咬勁十足。" },
      { "category": "在地瓜果", "name": "愛文芒果", "price": 90, "description": "夏日限定，果香濃郁、入口即化。" },
      { "category": "在地瓜果", "name": "珍珠芭樂", "price": 30, "description": "質地清脆，富含膳食纖維。" },
      { "category": "進口水果", "name": "加州無籽紅葡萄", "price": 150, "description": "免剝皮免吐籽，皮薄肉脆，大人小孩都愛。" }, { "category": "在地瓜果", "name": "麻豆文旦", "price": 70, "description": "果肉飽滿、甘甜多汁，中秋送禮首選。" },
      { "category": "在地瓜果", "name": "旗山香蕉", "price": 15, "description": "濃郁香甜，口感扎實，最天然的能量補給。" },
      { "category": "在地瓜果", "name": "大湖草莓", "price": 180, "description": "香氣撲鼻，外觀精緻，酸酸甜甜的幸福滋味。" },
      { "category": "在地瓜果", "name": "聖女小番茄", "price": 50, "description": "皮薄多汁，一口一個剛剛好。" },
      { "category": "在地瓜果", "name": "枕頭山水蜜桃", "price": 130, "description": "產自高山，果肉柔嫩、香氣多汁。" },
      { "category": "進口水果", "name": "泰國金枕頭榴槤", "price": 350, "description": "果肉綿密如卡士達，氣味濃郁獨特。" },
      { "category": "進口水果", "name": "智利藍莓", "price": 100, "description": "精選小漿果，富含花青素，酸甜開胃。" },
      { "category": "在地瓜果", "name": "巨無霸西瓜", "price": 110, "description": "消暑解渴聖品，果肉鮮紅爽脆。" }, { "category": "在地瓜果", "name": "美濃香瓜", "price": 65, "description": "外皮淡綠、果肉厚實，帶有清淡蜜香。" },
      { "category": "進口水果", "name": "澳洲蜜柑", "price": 40, "description": "皮薄好剝，果肉鮮甜且多汁。" }
    ];

    try {
      WriteBatch batch=FirebaseFirestore.instance.batch();
      for (var i in fruitData) {
        DocumentReference docRef=fruitCollection.doc();
        batch.set(docRef, i);
      }
      await batch.commit();
    }
    catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('匯入失敗: $e'),));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('我的賣場'),
        actions: [
          IconButton(
            onPressed: ()=>importDataToFirestore(context),
            icon: Icon(Icons.upload_file,),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('fruits1').snapshots(),
        builder: (contedxt, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          var docs=snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Text('請匯入水果資料!'),);
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data=docs[index].data();
              Fruit fruit=Fruit(
                id: docs[index].id,
                name: data['name'],
                description: data['description'],
                category: data['category'],
                price: data['price'],
              );
              return Card(
                margin: EdgeInsets.all(8),
                child: ListTile(
                  title: Text("${fruit.name} (${fruit.category})"),
                  subtitle: Text("${fruit.description}\n 價格: \$${fruit.price}"),
                  isThreeLine: true,
                  trailing: IconButton(
                    onPressed: () {
                      Provider.of<CartProvider>(context, listen: false).addToCart(fruit);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${fruit.name}已加入購物車"), duration: Duration(seconds: 1),));
                    },
                    icon: Icon(Icons.add_shopping_cart, color: Colors.green),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}


class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  @override
  Widget build(BuildContext context) {
    var cart=Provider.of<CartProvider>(context);
    return Scaffold(
      appBar: AppBar(title: Text('購物車頁面')),
      body: cart._cartItems.isEmpty? Center(child: Text('無商品'),):
            Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.cartItems.length,
                    itemBuilder: (context, index) {
                      var item=cart.cartItems[index];
                      return ListTile(
                        title: Text(item.name),
                        subtitle: Text('單價: \$${item.price} | 小計: \$${item.price*item.quantity}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: ()=>cart.updateQuantity(item.id, -1),
                              icon: Icon(Icons.remove),
                            ),
                            Text('${item.quantity}', style: TextStyle(fontSize: 16,),),
                            IconButton(
                              onPressed: ()=>cart.updateQuantity(item.id, 1),
                              icon: Icon(Icons.add),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(16,),
                  color: Colors.grey,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('總計金額: \$${cart.totalPrice}', style: TextStyle(fontSize: 18,
                                                                             fontWeight: FontWeight.bold,),),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        onPressed: () {
                          cart.checkOut();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已儲存!'),));
                        },
                        child: Text('結帳', style: TextStyle(color: Colors.white),),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  Widget build(BuildContext context) {
    var cart=Provider.of<CartProvider>(context);
    return Scaffold(
      appBar: AppBar(title: Text('購買紀錄'),),
      body: cart.orderHistory.isEmpty?
            Center(child: Text('無消費紀錄'),):
            ListView.builder(
              itemCount: cart.orderHistory.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: EdgeInsets.all(10,),
                  child: Padding(
                    padding: EdgeInsets.all(12,),
                    child: Text(
                      cart.orderHistory[index],
                      style: TextStyle(fontSize: 14, height: 1.5,),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class FruitDetailPage extends StatefulWidget {
  final String fruitName;
  FruitDetailPage({super.key, required this.fruitName});

  @override
  State<FruitDetailPage> createState() => _FruitDetailPageState();
}

class _FruitDetailPageState extends State<FruitDetailPage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.fruitName}特惠詳情'),),
      body: FutureBuilder(
        future: FirebaseFirestore.instance.collection('fruits1').where('name', isEqualTo: widget.fruitName).limit(1).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return Center(child: Text('已下架!'),);
          var data=snapshot.data!.docs.first.data();
          Fruit fruit=Fruit(
            id: snapshot.data!.docs.first.id,
            name: data['name'],
            description: data['description'],
            category: data['category'],
            price: data['price'],
          );
          return Padding(
            padding: EdgeInsets.all(20,),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fruit.name, style: TextStyle(fontSize: 28,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green,),),
                SizedBox(height: 10,),
                Chip(label: Text(fruit.category),),
                SizedBox(height: 20,),
                Text('商品特點: \n${fruit.description}', style: TextStyle(fontSize: 16,
                                                                         height: 1.5,),),
                SizedBox(height: 20,),
                Text('限時特價: \n${fruit.price}', style: TextStyle(fontSize: 24,
                                                                   fontWeight: FontWeight.bold,
                                                                   color: Colors.orange,),),
                Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.add_shopping_cart, color: Colors.white,),
                    label: Text('立即搶購', style: TextStyle(fontSize: 18, color: Colors.white,),),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green,),
                    onPressed: () {
                      Provider.of<CartProvider>(context, listen: false).addToCart(fruit);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已加入購物車!'),));
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
