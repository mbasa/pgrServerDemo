import 'package:flutter/material.dart';

class DialogUtil {
  static void showOnSendDialog(BuildContext context, String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            height: 150.0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                CircularProgressIndicator(),
                SizedBox(
                  height: 12.0,
                ),
                Text(
                  msg,
                  style: TextStyle(fontSize: 12.0),
                  textAlign: TextAlign.center,
                )
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> showCustomDialog(
      BuildContext context, String title, String msg, String btnMsg,
      {Color titleColor = Colors.red}) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(msg),
          actions: <Widget>[
            ElevatedButton(
              child: Text(
                btnMsg,
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(primary: Color(0xff00ac7d)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  static Future<bool> showConfirmDialog(BuildContext context, String title,
      String msg, String cancelBtnMsg, String okBtnMsg,
      {Color titleColor = Colors.red}) async {
    return await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(msg),
          actions: <Widget>[
            ElevatedButton(
              child: Text(
                cancelBtnMsg,
                style: TextStyle(color: Color(0xff546e7a)),
              ),
              style: ElevatedButton.styleFrom(primary: Colors.white),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              child: Text(
                okBtnMsg,
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(primary: Color(0xff00ac7d)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }
}
