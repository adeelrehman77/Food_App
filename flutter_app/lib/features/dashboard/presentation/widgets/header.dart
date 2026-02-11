import 'package:flutter/material.dart';

class Header extends StatelessWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: Colors.white,
      child: Row(
        children: [
          // Mobile Menu Button (Visible only on small screens - handled by parent usually, but placeholder here)
          if (MediaQuery.of(context).size.width < 800)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          
          // Tenant Name
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kitchen: Downtown Branch', // Validated dynamic data later
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                'Tenant ID: #12345',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          
          const Spacer(),

          // Search Bar
          if (MediaQuery.of(context).size.width > 600)
            Container(
              width: 300,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                ),
              ),
            ),
          
          const SizedBox(width: 20),

          // Updates/Notifications
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),

          const SizedBox(width: 10),

          // User Profile
          const CircleAvatar(
            backgroundColor: Colors.blueAccent,
            child: Text('AD'),
          ),
        ],
      ),
    );
  }
}
