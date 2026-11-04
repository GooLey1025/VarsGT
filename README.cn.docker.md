> [English](README.md) | **中文**
>
> [Docker install](README.md) | [Local install](README.manual.md) | **中国大陆-Docker install** | [中国大陆-Local install](README.cn.manual.md)

# VarsGT

**VarsGT**（**Var**iants **G**eno**T**yping）用于把二代测序（NGS）reads 比对到预先定义的变异面板上并完成基因分型。面板可以是本仓库发布的水稻标记面板，也可以是用户自己的面板。流程按等位基因对面板中的 SNP、INDEL 和结构变异（SV）进行分型，并输出标准化 VCF，供下游分析使用，尤其是我们提供的 [RiceGPlex 网站](https://www.xhhuanglab.cn/tool/ricegplex/#/datasets)上的基因组选择模型。

# 安装

## Docker 镜像

使用腾讯云容器镜像：

```bash
docker pull ccr.ccs.tencentyun.com/goley04/varsgt:latest
```

镜像入口是 Nextflow。把工作目录挂载到 `/data`，并传入 Nextflow 参数，其中包括 `run /opt/varsgt/main.nf`。运行时使用镜像名 `ccr.ccs.tencentyun.com/goley04/varsgt:latest`。

## 图泛基因组索引

索引基于 42 个水稻基因组构建，大小约 1.5 GB。下载到即将挂载进容器的目录。

```sh
wget https://zenodo.org/records/2322/files/Nip-42rice_GraphPangenome_Index.zip?download=1 -O Nip-42rice_GraphPangenome_Index.zip
unzip Nip-42rice_GraphPangenome_Index.zip -d Nip-42rice_GraphPangenome_Index
```

## 水稻群体标记面板

仓库提供三个群体面板，按待测材料选择。文件位于 `cohort_panel_index/`。

**Rice655。** 自交系面板。标记集为 MSMP（Multi-Source Marker Panel），包含性状关联主效变异、全基因组主效变异、GWAS 主效变异和 RiceNavi QTN 变异。支持 QTN 育种推荐，适用于纯合自交材料。

**Rice3305。** 大规模自交系面板。标记集仅含全基因组主效变异，不含 QTN 标记，因此不提供育种推荐。但是该群体有大规模的多群体多环境表型数据。

**Rice1171。** 杂交稻面板，用于杂交稻育种，标记集与 Rice655 相同，同为 MSMP。

这些面板在已发布的 [Aquila 基因组选择模型](https://github.com/GooLey1025/Aquila-GS)中可预测的性状，见 [RiceGPlex 网站](https://www.xhhuanglab.cn/tool/ricegplex/#/datasets)。

# 快速测试

先完成上面的索引下载，再在 VarsGT 目录中运行。测试读取 `test_fq/` 中的 FASTQ，结果写入 `test_rice655-ref_out`。该命令对 Rice655 面板分型，大约需要 15 分钟。

```sh
wget https://zenodo.org/records/2322/files/test_fq.zip?download=1 -O test_fq.zip
unzip test_fq.zip -d test_fq

docker run --rm \
  -v "${PWD}:/data" \
  -w /data \
  ccr.ccs.tencentyun.com/goley04/varsgt:latest \
  run /opt/varsgt/main.nf \
  --fq_dir_glob "test_fq/*.reads{1,2}.fastq.gz" \
  --index_dir Nip-42rice_GraphPangenome_Index \
  --panel_dir cohort_panel_index/rice655_index \
  --project test_rice655-ref \
  --out_dir test_rice655-ref_out \
  -work-dir work \
  -resume
```

# 使用方法

`--fq_dir_glob`、`--index_dir`、`--panel_dir`、`--out_dir` 和 `-work-dir` 中的路径在容器内解析。使用 `-v "${PWD}:/data"` 和 `-w /data` 时，相对路径就是挂载目录中的路径。

```sh
docker run --rm \
  -v "${PWD}:/data" \
  -w /data \
  ccr.ccs.tencentyun.com/goley04/varsgt:latest \
  run /opt/varsgt/main.nf \
  --fq_dir_glob "/data/reads/*.read{1,2}.fastq.gz" \
  --index_dir /data/Nip-42rice_GraphPangenome_Index \
  --panel_dir /data/cohort_panel_index/rice655_index \
  --project rice655_task \
  --out_dir /data/results/rice655_task \
  -work-dir /data/work \
  -resume
```

- `--fq_dir_glob` 是双端 FASTQ 的匹配模式，例如 `/data/reads/*.read{1,2}.fastq.gz`。
- `--index_dir` 是 Giraffe 图索引，必须包含 `Nip_42_rice.gbz`、`Nip_42_rice.hapl`、`Nip.chrnum.sorted.fa`，以及恰好一个 `*.graph_prefix.txt` 和一个 `*.ref_order.txt`。
- `--panel_dir` 是分型面板，例如 `cohort_panel_index/rice655_index`。其中必须有恰好一个 `*.ref_panel.vcf.gz`、SNP 和 INDEL 位点文件（`*.snp.sites.vcf`、`*.indel.sites.vcf`），以及 `*.delly.sv.sites.bcf`。
- `--project` 是写入结果的项目名。
- `--out_dir` 是最终文件的输出目录。
- `-work-dir` 是 Nextflow 的工作目录。
- `-resume` 用于恢复上一次 Nextflow 运行。传入同一个缓存名即可复用该次运行，也可以传入运行名或 session ID，例如 `-resume last` 或 `-resume 4dc3bb0e-...`。中断的运行也用它继续。

同一套 reads 只需更换 `--panel_dir`，例如换成 `cohort_panel_index/rice3305_index` 或 `cohort_panel_index/rice1171_index`，并用 `-resume` 指向同一个 mapping cache。流程会直接在对应面板上分型，不再重复比对 reads。

## 构建分型面板

Rice655、Rice3305 和 Rice1171 面板已经放在 `cohort_panel_index/`。若要从自己的最终标记 VCF 构建面板，见[构建 VarsGT 分型标记面板](docs/make_ref.md)。
