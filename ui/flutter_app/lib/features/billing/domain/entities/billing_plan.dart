enum BillingPlan {
  free('free'),
  proMonthly('pro_monthly'),
  proYearly('pro_yearly'),
  lifetime('lifetime');

  const BillingPlan(this.id);

  final String id;

  static BillingPlan? tryParse(String value) {
    for (final plan in BillingPlan.values) {
      if (plan.id == value) {
        return plan;
      }
    }
    return null;
  }
}
