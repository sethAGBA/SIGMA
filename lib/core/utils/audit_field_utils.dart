/// Valeur d'audit traçable : username de session ou repli explicite.
String auditFieldValue(String username) =>
    username.isNotEmpty ? username : 'Inconnu';
