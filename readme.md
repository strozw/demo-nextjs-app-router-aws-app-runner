# Demo for Deploy Next.js App Router to AWS App Runner

[Vercel の App Router Playground](https://vercel.com/templates/next.js/app-directory) を AWS App Runner にデプロイするデモです。

# デプロイに必要なもの

`terraform/` ディレクトリに、`sample.terraform.tfvars` を元にした、必要な情報を記述した `terraform.tfvars` を用意し、以下を実行する。

```sh
terraform init
terraform apply
```

出力されたものうち、以下を Github Actions の Secrets に設定する。

|`terraform ouput`|Github Actions Secrets|
|---|---|
| aws_region |  AWS_REGION |
| github_assume_role_arn |  AWS_ASSUME_ROLE_ARN|
| apprunner_access_role_arn| APP_RUNNER_ACCESS_ROLE_ARN |
| ecr_repository_name | ECR_REPOSITORY |
