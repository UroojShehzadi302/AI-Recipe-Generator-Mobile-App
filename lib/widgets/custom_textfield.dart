import 'package:flutter/material.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool isPassword;
  final TextInputType keyboardType;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.icon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool obscure = true;
  bool isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (value) {
        setState(() {
          isFocused = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFocused
                ? const Color(0xff8B5E3C)
                : const Color(0xffD8CFC7),
            width: isFocused ? 1.5 : 1,
          ),
        ),
        child: TextField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: widget.isPassword ? obscure : false,
          cursorColor: const Color(0xff8B5E3C),
          style: const TextStyle(fontSize: 16, color: Colors.black87),
          decoration: InputDecoration(
            border: InputBorder.none,

            // Floating Label
            labelText: widget.hintText,
            floatingLabelBehavior: FloatingLabelBehavior.auto,

            labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 15),

            floatingLabelStyle: const TextStyle(
              color: Color(0xff8B5E3C),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),

            alignLabelWithHint: true,

            prefixIcon: Icon(
              widget.icon,
              color: const Color(0xff8B5E3C),
              size: 22,
            ),

            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 18,
            ),

            suffixIcon: widget.isPassword
                ? IconButton(
                    splashRadius: 18,
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        obscure = !obscure;
                      });
                    },
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
