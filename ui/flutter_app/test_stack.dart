import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          Container(width: 500, height: 500, color: Colors.blue), // ensures outer stack is 500x500
          Builder(
            builder: (context) {
              return Stack(
                children: [
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Builder(builder: (c) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        print("Inner stack size: ${c.size}");
                        print("Context size of stack: ${context.size}");
                      });
                      return Text('Hello');
                    }),
                  )
                ],
              );
            }
          )
        ],
      )
    )
  ));
}
