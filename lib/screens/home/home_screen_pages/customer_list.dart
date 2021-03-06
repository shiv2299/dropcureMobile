import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dropcure/Theme/colors.dart';
import 'package:dropcure/Theme/url.dart';
import 'package:dropcure/models/order.dart';
import 'package:dropcure/models/order_status.dart';
import 'package:dropcure/screens/home/widgets/change_status_alert.dart';
import 'package:dropcure/screens/home/widgets/delivery_count_widget.dart';
import 'package:dropcure/screens/home/widgets/info_card.dart';
import 'package:dropcure/screens/login/widgets/show_alert.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerList extends StatefulWidget {
  final time;
  final openDrawer;

  CustomerList(this.time, this.openDrawer, {Key key}) : super(key: key);

  @override
  CustomerListState createState() => CustomerListState();
}

class CustomerListState extends State<CustomerList> {
  List<Order> orders;
  List<Order> filteredOrders;
  bool isLoaded = false;
  bool ordersPresent = false;
  DateTime now;
  Map<String, dynamic> deliveries = {};
  int selectedOrder = -1;
  int c = -1;
  final ScrollController _scrollController = ScrollController();
  String currentDate = "";
  getOrders() async {
    print(now.toString());
    c++;
    deliveries = {};
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String id = prefs.getString('user_id');
    // try {
    Dio dio = Dio();
    URL url = URL();
    FormData userData = new FormData.fromMap({
      "user_id": id,
    });
    Response response =
        await dio.post(url.url + "get_all_order.php", data: userData);
    Map<String, dynamic> data = json.decode(response.data);
    print(data);
    OrderStatus order = OrderStatus.fromRawJson(response.data);

    if (order.status) {
      setState(() {
        deliveries.putIfAbsent("completedDeliveries",
            () => data["data"]["order_count"]["complete"]);
        deliveries.putIfAbsent(
            "openDeliveries", () => data["data"]["order_count"]["open"]);
        deliveries.putIfAbsent(
            "cancelledDeliveries", () => data["data"]["order_count"]["cancel"]);
        deliveries.putIfAbsent(
            "totalDeliveries", () => data["data"]["order_count"]["deliveries"]);
        orders = order.data;
        filterByDate(selectedOrder);
        if (orders.length < 1) {
          ordersPresent = false;
        } else {
          ordersPresent = true;
        }
        isLoaded = true;
      });
    } else {
      setState(() {
        if (data["data"].length > 0) {
          print(data["data"]["order_count"]);
          deliveries.putIfAbsent("completedDeliveries",
              () => data["data"]["order_count"]["complete"]);
          deliveries.putIfAbsent(
              "openDeliveries", () => data["data"]["order_count"]["open"]);
          deliveries.putIfAbsent("cancelledDeliveries",
              () => data["data"]["order_count"]["cancel"]);
          deliveries.putIfAbsent("totalDeliveries",
              () => data["data"]["order_count"]["deliveries"]);
        }
        ordersPresent = false;
        isLoaded = true;
      });
    }
    // } catch (e) {
    //   showDialog(
    //       context: context,
    //       builder: (ctx) {
    //         return RetryDialog("Something Went Wrong!", getOrders);
    //       },
    //       barrierDismissible: false);
    // }
  }

  changeStatus(action, index) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String userId = prefs.get("user_id");
      Dio dio = Dio();
      URL url = URL();
      FormData orderData = new FormData.fromMap({
        "order_id": filteredOrders[index].orderId,
        "user_id": userId,
        "type": action
      });
      Response response =
          await dio.post(url.url + "order_action.php", data: orderData);
      var data = json.decode(response.data);
      if (data["status"]) {
        getOrders();
      } else {
        showDialog(
            context: context,
            builder: (ctx) {
              return ShowAlert(
                  "Error Changing Status!", data["message"].toString());
            });
      }
    } catch (e) {
      Fluttertoast.showToast(
          msg: "Something went wrong!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          fontSize: 16.0);
    }
  }

  changeOrderStatus(index) {
    String msg = "";
    if (filteredOrders[index].orderStatus.toString().compareTo("1") == 0) {
      msg = "cancel";
    } else if (filteredOrders[index].orderStatus.toString().compareTo("3") ==
            0 ||
        filteredOrders[index].orderStatus.toString().compareTo("0") == 0) {
      if (filteredOrders[index].noteStatus.toString() == "0") {
        Fluttertoast.showToast(
            msg: "Verify drop number!",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            fontSize: 16.0);
        return;
      }
      msg = "complete";
    } else {
      return;
    }
    showDialog(
        context: context,
        builder: (_) {
          return ChangeStatusAlert(msg, changeStatus, index);
        });
  }

  @override
  void initState() {
    super.initState();
    getOrders();
    now = widget.time;
    currentDate = DateFormat('EEEE, MMMM d, yyyy').format(now);
  }

  filterList(int orderStatus) {
    // setState(() {
    selectedOrder = orderStatus;
    if (orderStatus == -1) {
      filteredOrders = List.from(filteredOrders);
    } else if (orderStatus == 2) {
      filteredOrders = List.from(filteredOrders.where((element) =>
          int.parse(element.orderStatus) == 2 ||
          int.parse(element.orderStatus) == 3));
    } else {
      filteredOrders = List.from(filteredOrders
          .where((element) => int.parse(element.orderStatus) == orderStatus));
    }
    if (c > 0) {
      _scrollController.animateTo(
        0.0,
        curve: Curves.easeOut,
        duration: const Duration(milliseconds: 300),
      );
    }
    // });
  }

  filterByDate(int index) {
    print("FILTER BY DATE");
    deliveries["cancelledDeliveries"] = 0;
    deliveries["openDeliveries"] = 0;
    deliveries["completedDeliveries"] = 0;
    setState(() {
      filteredOrders = List.from(orders.where((element) {
        if (now.difference(element.createdAt).inDays == 0) {
          print(element.orderStatus.runtimeType);
          if (element.orderStatus == "2" || element.orderStatus == "3") {
            deliveries["cancelledDeliveries"]++;
          } else if (element.orderStatus == "0") {
            deliveries["openDeliveries"]++;
          } else if (element.orderStatus == "1") {
            deliveries["completedDeliveries"]++;
          }
          return true;
        }
        return false;
      }));
      deliveries["totalDeliveries"] = filteredOrders.length;
      filterList(index);
    });
  }

  order(index) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: GestureDetector(
        child: InfoCard(filteredOrders[index], index + 1, getOrders),
        onTap: () {
          if (filteredOrders[index].orderStatus != "0")
            changeOrderStatus(index);
        },
      ),
    );
  }

  change(newTime) {
    now = newTime;
    filterByDate(-1);
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    var screenWidth = size.width;
    return isLoaded
        ? Column(
            children: <Widget>[
              Container(
                margin: EdgeInsets.only(top: 15),
                padding: EdgeInsets.only(top: 5, bottom: 20),
                width: screenWidth,
                color: Colors.white,
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        "Delivery Status Dashboard",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      SizedBox(
                        height: 15,
                      ),
                      GestureDetector(
                        child: Text(
                          DateFormat('EEEE, MMMM d, yyyy').format(now),
                          style: TextStyle(
                              fontSize: 24,
                              color: pinkColor,
                              fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          widget.openDrawer();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.only(bottom: 10),
                child: DeliveryCountWidget(
                  deliveries["totalDeliveries"] ??= 0,
                  deliveries["completedDeliveries"] ??= 0,
                  deliveries["openDeliveries"] ??= 0,
                  deliveries["cancelledDeliveries"] ??= 0,
                  isClickable: true,
                  onClick: filterByDate,
                  selected: selectedOrder,
                  small: true,
                ),
                color: Colors.white,
              ),
              SizedBox(
                height: 10,
              ),
              Expanded(
                child: ordersPresent
                    ? ListView.builder(
                        controller: _scrollController,
                        itemCount: filteredOrders.length,
                        itemBuilder: (ctx, index) {
                          return order(index);
                        },
                      )
                    : Center(
                        child: Text(
                          "No orders completed yet",
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
              ),
            ],
          )
        : Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(pinkColor),
            ),
          );
  }
}
