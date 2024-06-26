import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/get_rx.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';

import '../../../../../models/truck_model.dart';
import '../../../../../utils/app_colors.dart';

class AdminHomeController extends GetxController {
  RxList<Map<String, dynamic>> trucksData = RxList<Map<String, dynamic>>();
  RxList<Truck> truckList = <Truck>[].obs;
  RxBool isLoading = true.obs;

  RxString date = ''.obs;
  RxString selectedDate = ''.obs;
  Rx<User?> user = Rx<User?>(null);
  final box = GetStorage();

  RxInt lilaCount = 0.obs;
  RxInt containerCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _setupAuthListener();
    ever(selectedDate, (_) => fetchTrucks());
    Future.delayed(Duration(seconds: 2), () {
      isLoading.value = false;
    });
  }

  void _setupAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      this.user.value = user;
      if (user != null) {
        fetchTrucks();
      } else {
        trucksData.clear();
        lilaCount.value = 0;
        containerCount.value = 0;
      }
    });
  }

  void addTruckData(Map<String, dynamic> data) {
    trucksData.add(data);
    updateCounts();
    update();
  }

  void removeTruckData(Map<String, dynamic> data) {
    trucksData.remove(data);
    updateCounts();
    update();
  }


Future<void> fetchTrucks() async {
  try {
    isLoading.value = true;
    print('Fetching trucks...');
    print('Selected Date: ${selectedDate.value}');

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // If user is not logged in, return without fetching trucks
      return;
    }

    String adminId = user.uid;

    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('trucks')
        .where('adminId', isEqualTo: adminId)
        .get();

    final List<Truck> trucksData = querySnapshot.docs.map((doc) {
      return Truck.fromJson(doc.data() as Map<String, dynamic>);
    }).toList();

    Map<String, List<Container>> groupedContainers = {};
    int totalContainers = 0;
    int totalQuantities = 0;

    for (var truck in trucksData) {
      List<Container> filteredContainers;

      if (selectedDate.value.isEmpty) {
        filteredContainers = truck.containers;  // No date filtering, include all containers
      } else {
        filteredContainers = truck.containers.where((container) {
          print('Comparing Container Date: ${container.date} with Selected Date: ${selectedDate.value}');
          return container.date == selectedDate.value;
        }).toList();
      }

      if (filteredContainers.isNotEmpty) {
        totalContainers += filteredContainers.length;
        for (var container in filteredContainers) {
          totalQuantities += container.quantity;
          if (!groupedContainers.containsKey(truck.truckName)) {
            groupedContainers[truck.truckName] = [];
          }
          groupedContainers[truck.truckName]!.add(container);
        }
      }
    }

    lilaCount.value = totalContainers;
    containerCount.value = totalQuantities;
    truckList.value = groupedContainers.entries.map((entry) {
      return Truck(
        adminId: trucksData
            .firstWhere((truck) => truck.truckName == entry.key)
            .adminId,
        truckName: entry.key,
        containers: entry.value,
        totalCount: entry.value.length,
        totalSuccess: entry.value
            .where((container) => container.scanSuccess > 0)
            .length,
        totalFail:
            entry.value.where((container) => container.scanFailed > 0).length,
      );
    }).toList();
    truckList.sort((a, b) => a.truckName.compareTo(b.truckName));
    isLoading.value = false;
    print('Truck List: $truckList');
    print('Total Containers: $totalContainers');
    print('Total Quantities: $totalQuantities');
  } catch (error) {
    isLoading.value = false;
    print('Error fetching trucks: $error');
  }
}



  void updateCounts() {
    int totalContainers = trucksData.length;
    int totalQuantities = trucksData.fold(0,
        (sum, item) => sum + (item['quantity'] as num).toInt()); // Cast to int
    lilaCount.value = totalContainers;
    containerCount.value = totalQuantities;
  }
}

Map<K, List<V>> groupBy<V, K>(Iterable<V> values, K Function(V) keyFunction) {
  var map = <K, List<V>>{};
  for (var element in values) {
    var key = keyFunction(element);
    map.putIfAbsent(key, () => <V>[]);
    map[key]!.add(element);
  }
  return map;
}
