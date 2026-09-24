# ExternalDNS IAM Role (for Pod Identity)
resource "aws_iam_role" "externaldns_role" {
  name = "${local.name}-externaldns-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# Attach AWS Managed Route53 Full Access
resource "aws_iam_role_policy_attachment" "externaldns_managed_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonRoute53FullAccess"
  role = aws_iam_role.externaldns_role.name
}

output "externaldns_role_arn" {
  value = aws_iam_role.externaldns_role.arn
}