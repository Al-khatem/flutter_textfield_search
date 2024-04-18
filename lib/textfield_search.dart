import 'package:flutter/material.dart';
import 'dart:async';

import 'package:textfield_search/search_model.dart';

class TextFieldSearch extends StatefulWidget {
  /// A default list of values that can be used for an initial list of elements to select from
  final List<TextFiledSearchModel> initialList;

  /// A controller for an editable text field
  final TextEditingController controller;

  final Brightness? keyboardAppearance;

  final FormFieldValidator<String>? validator;

  final Color? dropdownColor;
  final Color? clearIconColor;

  final void Function(dynamic value) onChanged;
  final dynamic value;

  /// Used for customizing the display of the TextField
  final InputDecoration? decoration;

  /// Used for customizing the style of the text within the TextField
  final TextStyle? textStyle;

  /// Used for customizing the scrollbar for the scrollable results
  final ScrollbarDecoration? scrollbarDecoration;

  /// The minimum length of characters to be entered into the TextField before executing a search
  final int minStringLength;

  /// The number of matched items that are viewable in results
  final int itemsInView;

  /// Creates a TextFieldSearch for displaying selected elements and retrieving a selected element
  const TextFieldSearch({
    Key? key,
    required this.initialList,
    required this.controller,
    this.keyboardAppearance,
    this.validator,
    this.textStyle,
    this.decoration,
    this.scrollbarDecoration,
    this.itemsInView = 3,
    this.minStringLength = 2,
    this.dropdownColor,
    this.clearIconColor,
    required this.onChanged,
    this.value,
  }) : super(key: key);

  @override
  _TextFieldSearchState createState() => _TextFieldSearchState();
}

class _TextFieldSearchState extends State<TextFieldSearch> {
  late final FocusNode _focusNode = FocusNode();
  late OverlayEntry _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  List<TextFiledSearchModel> filteredList = [];
  bool loading = false;
  final _debouncer = Debouncer(milliseconds: 50);
  static const itemHeight = 55;
  bool? itemsFound;
  // ScrollController _scrollController = ScrollController();

  void resetList() {
    List<TextFiledSearchModel> tempList = [];
    setState(() {
      // after loop is done, set the filteredList state from the tempList
      this.filteredList = tempList;
      this.loading = false;
    });
    // mark that the overlay widget needs to be rebuilt
    this._overlayEntry.markNeedsBuild();
  }

  void setLoading() {
    if (!this.loading) {
      setState(() {
        this.loading = true;
      });
    }
  }

  void resetState(List<TextFiledSearchModel> tempList) {
    setState(() {
      // after loop is done, set the filteredList state from the tempList
      this.filteredList = tempList;
      this.loading = false;
      // if no items are found, add message none found
      itemsFound = tempList.length == 0 && widget.controller.text.isNotEmpty
          ? false
          : true;
    });
    // mark that the overlay widget needs to be rebuilt so results can show
    this._overlayEntry.markNeedsBuild();
  }

  void updateList() {
    this.setLoading();
    // set the filtered list using the initial list
    this.filteredList = widget.initialList;

    // create an empty temp list
    List<TextFiledSearchModel> tempList = [];
    // loop through each item in filtered items
    for (int i = 0; i < filteredList.length; i++) {
      // lowercase the item and see if the item contains the string of text from the lowercase search
      if (this
          .filteredList[i]
          .text
          .toLowerCase()
          .contains(widget.controller.text.toLowerCase())) {
        // if there is a match, add to the temp list
        tempList.add(this.filteredList[i]);
      }
    }
    // helper function to set tempList and other state props
    this.resetState(tempList);
  }

  void initState() {
    super.initState();

    // throw error if we don't have an initial list or a future
    // ignore: unnecessary_null_comparison
    if (widget.initialList == null) {
      throw ('Error: Missing required initial list or future that returns list');
    }

    Future.delayed(Duration.zero, () {
      if (widget.value != null) {
        final selectedValue = widget.initialList
            .firstWhere((element) => element.value == widget.value);

        widget.controller.text = selectedValue.text;
        widget.onChanged(selectedValue.value);
      }
    });

    // add event listener to the focus node and only give an overlay if an entry
    // has focus and insert the overlay into Overlay context otherwise remove it
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        this._overlayEntry = this._createOverlayEntry();
        Overlay.of(context).insert(this._overlayEntry);
      } else {
        this._overlayEntry.remove();
        // check to see if itemsFound is false, if it is clear the input
        // check to see if we are currently loading items when keyboard exists, and clear the input
        if (itemsFound == false || loading == true) {
          // reset the list so it's empty and not visible
          resetList();
          widget.controller.clear();
        }
        // if we have a list of items, make sure the text input matches one of them
        // if not, clear the input
        if (filteredList.length > 0) {
          bool textMatchesItem = false;
          textMatchesItem = filteredList.contains(widget.controller.text);

          if (textMatchesItem == false) widget.controller.clear();
          resetList();
        }
      }
    });
  }

  ListView _listViewBuilder(context) {
    if (itemsFound == false) {
      return ListView(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        // controller: _scrollController,
        children: <Widget>[
          ListTile(
            onTap: () {
              // clear the text field controller to reset it
              widget.controller.clear();
              setState(() {
                itemsFound = false;
              });
              // reset the list so it's empty and not visible
              resetList();
              // remove the focus node so we aren't editing the text
              FocusScope.of(context).unfocus();
            },
            title: Text('No matching items.', style: widget.textStyle),
            trailing: Icon(Icons.cancel, color: widget.clearIconColor),
          ),
        ],
      );
    }
    return ListView.builder(
      itemCount: filteredList.length,
      itemBuilder: (context, i) {
        return TextFieldTapRegion(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // set the controller value to what was selected
                setState(() {
                  // if we have a label property, and getSelectedValue function
                  // send getSelectedValue to parent widget using the label property
                  widget.controller.text = filteredList[i].text;
                  widget.onChanged(filteredList[i].value);
                });
                // reset the list so it's empty and not visible
                resetList();
                // remove the focus node so we aren't editing the text
                // FocusScope.of(context).unfocus();
              },
              child: ListTile(
                title: Text(filteredList[i].text, style: widget.textStyle),
              ),
            ),
          ),
        );
      },
      padding: EdgeInsets.zero,
      shrinkWrap: true,
    );
  }

  /// A default loading indicator to display when executing a Future
  Widget _loadingIndicator() {
    return Container(
      width: 50,
      height: 50,
      child: Center(
        child: CircularProgressIndicator.adaptive(
          valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.secondary),
        ),
      ),
    );
  }

  Widget decoratedScrollbar(child) {
    if (widget.scrollbarDecoration is ScrollbarDecoration) {
      return Theme(
        data: Theme.of(context)
            .copyWith(scrollbarTheme: widget.scrollbarDecoration?.theme),
        child: Scrollbar(child: child),
      );
    }

    return Scrollbar(child: child);
  }

  Widget? _listViewContainer(context) {
    if (itemsFound == true && filteredList.length > 0 ||
        itemsFound == false && widget.controller.text.length > 0) {
      return Container(
          color: widget.dropdownColor,
          height: calculateHeight().toDouble(),
          child: decoratedScrollbar(_listViewBuilder(context)));
    }
    return null;
  }

  num heightByLength(int length) {
    return itemHeight * length;
  }

  num calculateHeight() {
    if (filteredList.length > 1) {
      if (widget.itemsInView <= filteredList.length) {
        return heightByLength(widget.itemsInView);
      }

      return heightByLength(filteredList.length);
    }

    return itemHeight;
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    Size overlaySize = renderBox.size;
    Size screenSize = MediaQuery.of(context).size;
    double screenWidth = screenSize.width;
    return OverlayEntry(
      builder: (context) => Positioned(
        width: overlaySize.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, overlaySize.height + 5.0),
          child: Material(
            elevation: 4.0,
            child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: screenWidth,
                  maxWidth: screenWidth,
                  minHeight: 0,
                  maxHeight: calculateHeight().toDouble(),
                ),
                child: loading
                    ? _loadingIndicator()
                    : _listViewContainer(context)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: this._layerLink,
      child: TextFormField(
        controller: widget.controller,
        keyboardAppearance: widget.keyboardAppearance,
        validator: widget.validator,
        focusNode: this._focusNode,
        decoration: widget.decoration,
        style: widget.textStyle,
        onTap: () {
          _debouncer.run(() {
            setState(() {
              updateList();
            });
          });
        },
        onChanged: (String value) {
          _debouncer.run(() {
            setState(() {
              updateList();
            });
          });

          if (value.isEmpty) {
            widget.onChanged(null);
          }
        },
      ),
    );
  }
}

class Debouncer {
  /// A length of time in milliseconds used to delay a function call
  final int? milliseconds;

  /// A callback function to execute
  VoidCallback? action;

  /// A count-down timer that can be configured to fire once or repeatedly.
  Timer? _timer;

  /// Creates a Debouncer that executes a function after a certain length of time in milliseconds
  Debouncer({this.milliseconds});

  run(VoidCallback action) {
    if (_timer != null) {
      _timer?.cancel();
    }
    _timer = Timer(Duration(milliseconds: milliseconds!), action);
  }
}

class ScrollbarDecoration {
  const ScrollbarDecoration({
    required this.controller,
    required this.theme,
  });

  /// {@macro flutter.widgets.Scrollbar.controller}
  final ScrollController controller;

  /// {@macro flutter.widgets.ScrollbarThemeData}
  final ScrollbarThemeData theme;
}
