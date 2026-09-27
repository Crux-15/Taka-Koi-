import 'package:flutter/material.dart';

/// A custom text field with label, hint, icon, and validation support.
class AppTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool   isPassword;
  final IconData? prefixIcon;
  final Widget? suffix;
  final int maxLines;
  final int? maxLength;
  final bool readOnly;
  final VoidCallback? onTap;
  final void Function(String)? onChanged;
  final TextInputAction textInputAction;
  final FocusNode? focusNode;
  final void Function(String)? onFieldSubmitted;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType    = TextInputType.text,
    this.isPassword      = false,
    this.prefixIcon,
    this.suffix,
    this.maxLines        = 1,
    this.maxLength,
    this.readOnly        = false,
    this.onTap,
    this.onChanged,
    this.textInputAction = TextInputAction.next,
    this.focusNode,
    this.onFieldSubmitted,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:      widget.controller,
      validator:       widget.validator,
      keyboardType:    widget.keyboardType,
      obscureText:     widget.isPassword && _obscure,
      maxLines:        widget.isPassword ? 1 : widget.maxLines,
      maxLength:       widget.maxLength,
      readOnly:        widget.readOnly,
      onTap:           widget.onTap,
      onChanged:       widget.onChanged,
      textInputAction: widget.textInputAction,
      focusNode:       widget.focusNode,
      onFieldSubmitted:widget.onFieldSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText:  widget.hint,
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, size: 20)
            : null,
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : widget.suffix,
        counterText: '', // hide character counter
      ),
    );
  }
}
