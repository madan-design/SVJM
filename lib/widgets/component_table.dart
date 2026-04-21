import 'package:flutter/material.dart';

class ComponentTable extends StatelessWidget {

  final List<Map<String,String>> components;

  const ComponentTable({super.key, required this.components});

  @override
  Widget build(BuildContext context) {

    return ListView.builder(
      itemCount: components.length,

      itemBuilder: (_,i){

        return Card(
          child: ListTile(
            title: Text(components[i]["description"] ?? ""),
            subtitle: Text("₹ ${components[i]["amount"]}"),
            trailing: Text(components[i]["machine"] ?? ""),
          ),
        );

      },
    );

  }
}