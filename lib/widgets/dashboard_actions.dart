import 'package:flutter/material.dart';
import './user_actions_menu.dart';

const List<Widget> dashboardAppBarActions = <Widget>[
  SizedBox(width: 8),
  Icon(Icons.notifications_none, color: Colors.black),
  SizedBox(width: 8),
  UserActionsButton(), // menú BLANCO con “Información personal” y “Ayuda”
  SizedBox(width: 12),
];
