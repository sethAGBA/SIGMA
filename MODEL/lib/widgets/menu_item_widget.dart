// import 'package:flutter/material.dart';
// import '../models/menu_item.dart';

// class MenuItemWidget extends StatelessWidget {
//   final MenuItem item;
//   final bool isSelected;
//   final VoidCallback onTap;

//   const MenuItemWidget({
//     required this.item,
//     required this.isSelected,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 200),
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//         decoration: BoxDecoration(
//           gradient: isSelected ? item.gradient : null,
//           borderRadius: BorderRadius.circular(12),
//           boxShadow: isSelected
//               ? [
//                   BoxShadow(
//                     color: item.gradient.colors.first.withOpacity(0.3),
//                     blurRadius: 12,
//                     offset: const Offset(0, 4),
//                   ),
//                 ]
//               : null,
//         ),
//         child: Row(
//           children: [
//             Container(
//               width: 36,
//               height: 36,
//               decoration: BoxDecoration(
//                 color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Icon(
//                 item.icon,
//                 color: Colors.white,
//                 size: 20,
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Text(
//                 item.title,
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 14,
//                   fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
//                 ),
//               ),
//             ),
//             if (isSelected)
//               Container(
//                 width: 4,
//                 height: 20,
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(2),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }




import 'package:flutter/material.dart';
import '../models/menu_item.dart';

class MenuItemWidget extends StatefulWidget {
  final MenuItem item;
  final bool isSelected;
  final ValueChanged<MenuItem>? onMenuItemSelected; // Callback for when a menu item (parent or child) is selected
  final VoidCallback? onTap;
  final String? selectedTitle; // Global selected title to highlight children
  final int level; // To control indentation for sub-items

  const MenuItemWidget({
    super.key,
    required this.item,
    required this.isSelected,
    this.onMenuItemSelected,
    this.onTap,
    this.selectedTitle,
    this.level = 0,
  });

  @override
  State<MenuItemWidget> createState() => _MenuItemWidgetState();
}

class _MenuItemWidgetState extends State<MenuItemWidget> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    // If the current item is selected, and it's a parent, expand it
    if (widget.isSelected && widget.item.children != null) {
      _isExpanded = true;
    }
  }

  @override
  void didUpdateWidget(covariant MenuItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the selection changes and this item is now selected, expand it
    if (widget.isSelected && !oldWidget.isSelected && widget.item.children != null) {
      _isExpanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.item.children != null && widget.item.children!.isNotEmpty) {
      // This is a parent item with children
      return Padding(
        padding: EdgeInsets.only(left: widget.level * 16.0), // Indent based on level
        child: ExpansionTile(
          key: PageStorageKey(widget.item.title), // Keep expansion state
          initiallyExpanded: _isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0), // Adjust padding
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: widget.isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.item.icon, color: Colors.white, size: 20),
          ),
          title: Text(
            widget.item.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          trailing: Icon(
            _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: Colors.white,
          ),
          children: widget.item.children!.map((childItem) {
            final childSelected = widget.selectedTitle != null ? childItem.title == widget.selectedTitle : false;
            return MenuItemWidget(
              item: childItem,
              isSelected: childSelected,
              onMenuItemSelected: widget.onMenuItemSelected,
              onTap: widget.onTap,
              selectedTitle: widget.selectedTitle,
              level: widget.level + 1, // Increase level for children
            );
          }).toList(),
        ),
      );
    } else {
      // This is a regular menu item (leaf node)
      return GestureDetector(
        onTap: () {
          // Prefer explicit onTap (legacy call sites). If not provided, fall back to onMenuItemSelected
          if (widget.onTap != null) {
            widget.onTap!();
          } else if (widget.onMenuItemSelected != null) {
            widget.onMenuItemSelected!(widget.item); // Call the callback with the selected item
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 16 + widget.level * 16.0, vertical: 12), // Adjust padding for indentation
          decoration: BoxDecoration(
            gradient: widget.isSelected ? widget.item.gradient : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: widget.isSelected
                ? [BoxShadow(color: widget.item.gradient.colors.first.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.item.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.item.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (widget.isSelected)
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)),
                ),
            ],
          ),
        ),
      );
    }
  }
}