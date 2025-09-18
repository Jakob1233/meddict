class LearningMaterialTypeData {
  const LearningMaterialTypeData({
    required this.value,
    required this.label,
    required this.assetPath,
  });

  final String value;
  final String label;
  final String assetPath;

  static const List<LearningMaterialTypeData> values = <LearningMaterialTypeData>[
    LearningMaterialTypeData(
      value: 'skripte',
      label: 'Skripte',
      assetPath: 'assets/images/materials/outline/skripte.svg',
    ),
    LearningMaterialTypeData(
      value: 'folien',
      label: 'Folien',
      assetPath: 'assets/images/materials/outline/folien.svg',
    ),
    LearningMaterialTypeData(
      value: 'zusammenfassungen',
      label: 'Zusammenfassungen',
      assetPath: 'assets/images/materials/outline/zusammenfassungen.svg',
    ),
    LearningMaterialTypeData(
      value: 'dokumente',
      label: 'Dokumente',
      assetPath: 'assets/images/materials/outline/dokumente.svg',
    ),
  ];

  static LearningMaterialTypeData byValue(String value) {
    final normalized = value.toLowerCase();
    return values.firstWhere(
      (type) => type.value == normalized,
      orElse: () => values.last,
    );
  }
}
