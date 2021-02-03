import '../../match_context.dart';
import '../../qr.dart';
import 'tree_types.dart';

class TreeMatcher {
  Tree _tree;
  MatchContext _cureentTree;

  // ignore: avoid_setters_without_getters
  set tree(Tree t) => _tree = t;

  MatchContext _getFirstMatch(MatchRoute match) {
    if (_cureentTree != null && match.route.key == _cureentTree.key) {
      return _cureentTree;
    }

    if (_cureentTree != null) {
      _cureentTree.dispoase();
      _cureentTree = null;
    }
    return match.toMatchContext();
  }

  MatchContext getMatch(String path) {
    path = path.trim();
    QR.log('matching for $path', isDebug: true);

    // Check if the same route
    if (path == QR.currentRoute.fullPath && _cureentTree != null) {
      return _cureentTree;
    }

    final match = _getMatch(path);

    final redirect = match.checkRedirect(path);
    if (redirect != null) {
      return getMatch(redirect);
    }

    // AddParams
    final params = Uri.parse(path).queryParametersAll;
    for (var item in params.entries) {
      if (item.value.length == 1) {
        match.params.addAll({item.key: item.value.first});
      } else if (item.value.isNotEmpty) {
        match.params.addAll({item.key: item.value});
      }
    }

    final oldParam = QR.currentRoute.params;

    // Set route info before onInit to use it when it needed.
    QR.currentRoute.fullPath = path;
    QR.currentRoute.params = match.getParames();
    QR.history.add(path);

    // Build Match Context
    var routeNode = match;
    final newTree = _getFirstMatch(routeNode);
    var contextNode = newTree;

    while (routeNode.childMatch != null) {
      final needInit =
          _needInit(routeNode, contextNode, oldParam, QR.currentRoute.params);

      if (needInit) {
        // Be sure to dispose and clean up the old context.
        if (contextNode.childContext != null) {
          contextNode.childContext.dispoase();
          contextNode.childContext = null;
        }
        contextNode.childContext = routeNode.childMatch.toMatchContext();
      }

      routeNode = routeNode.childMatch;

      // if there is params update the path on the last child
      // so he can update with new request with new params
      if (routeNode.childMatch == null && match.params.isNotEmpty) {
        contextNode.childContext = contextNode.childContext
            .copyWith(fullPath: path, isComponent: true, isNew: true);
      }
      contextNode = contextNode.childContext;
    }

    // Set current route info
    _cureentTree = newTree;
    return newTree;
  }

  bool _needInit(MatchRoute routeNode, MatchContext contextNode,
      Map<String, dynamic> oldParam, Map<String, dynamic> newParam) {
    if (contextNode.childContext == null) {
      // There is no previus context
      return true;
    }

    if (routeNode.childMatch.route.key != contextNode.childContext.key) {
      // This is new child route (it has new key)
      return true;
    }

    if (routeNode.childMatch.route.isComponent) {
      // It is component, try to see if it is new.
      final component = routeNode.childMatch.route.route.path.substring(1);
      final oldComponent = oldParam[component];

      if (oldComponent == null) {
        // Component is new
        return true;
      }

      final isTheSame =
          oldComponent.toString() != newParam[component].toString();

      return isTheSame;
    }

    return false;
  }

  MatchRoute _getMatch(String path) {
    final newRoute = Uri.parse(path).pathSegments;

    // Build Match Base
    var searchIn = _tree.routes;
    final match = MatchRoute.fromTree(
        routes: searchIn, path: newRoute.isEmpty ? '' : newRoute[0]);
    if (!match.found) return _notFound(path);
    searchIn = match.route.children;

    // Build Match Tree
    var childMatch = match;
    for (var i = 1; i < newRoute.length; i++) {
      childMatch.childMatch =
          MatchRoute.fromTree(routes: searchIn, path: newRoute[i]);
      if (!childMatch.childMatch.found) return _notFound(path);
      searchIn = childMatch.childMatch.route.children;
      childMatch = childMatch.childMatch;
    }

    // Set initRoute `/` if needed
    if (childMatch.route.hasChidlren) {
      final initRoute =
          Uri.parse(childMatch.route.route.initRoute ?? '').pathSegments;
      for (var segment in initRoute.isEmpty ? [''] : initRoute) {
        childMatch.childMatch =
            MatchRoute.fromTree(routes: searchIn, path: segment);
        if (!childMatch.childMatch.found) return _notFound(path);
        searchIn = childMatch.childMatch.route.children;
        childMatch = childMatch.childMatch;
      }
    }

    return match;
  }

  // Get match object for notFound Page.
  MatchRoute _notFound(String path) {
    QR.currentRoute.fullPath = path;
    final match = MatchRoute.fromTree(routes: _tree.routes, path: 'notfound');
    return match;
  }

  String findPathFromName(String name, Map<String, dynamic> params) {
    var path = _tree.treeIndex[name];
    assert(path != null, 'Path name not found');
    final pathParams = <String, dynamic>{};

    // Search for component params
    for (var param in params.entries) {
      if (path.contains(':${param.key}')) {
        path = path.replaceAll(':${param.key}', param.value.toString());
      } else {
        pathParams.addEntries([param]);
      }
    }

    // Replace old component
    for (var param in QR.params.entries) {
      if (path.contains(':${param.key}')) {
        path = path.replaceAll(':${param.key}', param.value.toString());
      }
    }

    if (pathParams.isNotEmpty) {
      path = '$path?';
      // Build the params
      for (var i = 0; i < pathParams.length; i++) {
        final param = pathParams.entries.toList()[i];
        path = '$path${param.key}=${param.value}';
        if (i != pathParams.length - 1) {
          path = '$path&';
        }
      }
    }
    return path;
  }
}
