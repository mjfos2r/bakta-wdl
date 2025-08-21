version 1.0
import "../structs/Structs.wdl"

workflow Bakta {

    meta {
        description: "Terra workflow to annotate draft bacterial assemblies using Bakta"
    }
    parameter_meta {
        file_prefix:        "Prefix to pass to bakta for file output naming."
        contigs:            "fasta file containing contig(s) to annotate."
        bakta_db:           "tar.gz containing the full bakta database for annotation."
        ncbi_compliant:     "[Default: False] Run bakta in Genbank compliance mode."
        complete:           "[Default: False] Is this a complete genome?"
        genus:              "[Default: Borrelia] genus to pass to bakta"
        species:            "[Default: burgdorferi] species to pass to bakta"
        strain:             "[Default: \'\'] strain to pass to bakta"
        locus_tag_prefix:   "Optional: NCBI assigned locus tag prefix."
        gram:               "[Default: \'?\'] Is this bacteria gram \'+\' or \'-\' ?"
    }
    input {
            String file_prefix
            File contigs
            File bakta_db
            Boolean ncbi_compliant = false
            Boolean complete = false
            String? genus
            String? species
            String? strain
            String? locus_tag_prefix
            String gram = "?"
    }
    call Annotate {
        input:
            file_prefix = file_prefix,
            contigs = contigs,
            bakta_db = bakta_db,
            ncbi_compliant = ncbi_compliant,
            complete = complete,
            genus = genus,
            species = species,
            strain = strain,
            locus_tag_prefix = locus_tag_prefix,
            gram = gram
    }
    output {
        File annotations_tsv = Annotate.annotations_tsv
        File gff3 = Annotate.gff3
        File gbff = Annotate.gbff
        File embl = Annotate.embl
        File fna = Annotate.fna
        File ffn = Annotate.ffn
        File faa = Annotate.faa
        File inference_metrics_tsv = Annotate.inference_metrics_tsv
        File hypotheticals_tsv = Annotate.hypotheticals_tsv
        File hypotheticals_faa = Annotate.hypotheticals_faa
        File summary_txt = Annotate.summary_txt
        File png = Annotate.png
        File svg = Annotate.svg
        File summary_json = Annotate.summary_json
    }
}

task Annotate {
    parameter_meta {
        file_prefix:        "Prefix to pass to bakta for file output naming."
        contigs:            "fasta file containing contig(s) to annotate."
        bakta_db:           "tar.gz containing the full bakta database for annotation"
        ncbi_compliant:     "[Default: False] Run bakta in Genbank compliance mode."
        complete:           "[Default: False] Is this a complete genome?"
        genus:              "[Default: Borrelia] genus to pass to bakta"
        species:            "[Default: burgdorferi] species to pass to bakta"
        strain:             "[Default: \'\'] strain to pass to bakta"
        locus_tag_prefix:   "Optional: NCBI assigned locus tag prefix."
        gram:               "[Default: \'?\'] Is this bacteria gram \'+\' or \'-\' ?"
    }
    input {
        String file_prefix
        File contigs
        File bakta_db

        Boolean ncbi_compliant = false
        Boolean complete = false
        String? genus
        String? species
        String? strain
        String? locus_tag_prefix
        String gram = "?"

        RuntimeAttr? runtime_attr_override
    }

    Int disk_size = 365 + 2 * ceil(size(bakta_db, "GB"))

    command <<<
        set -euxo pipefail
        NPROC=$(awk '/^processor/{print}' /proc/cpuinfo | wc -l)

        rapidgzip -c -d "~{bakta_db}" | tar -xvf - -C bakta_db --strip-components=1

        BAKTA_DB="bakta_db"

        echo "Beginning bakta annotation."
        bakta \
            --threads "$NPROC" \
            --prefix "~{file_prefix}" \
            --db "$BAKTA_DB" \
            --gram "~{gram}" \
            ~{if defined(genus)            then "--genus '" + genus            + "'" else ""} \
            ~{if defined(species)          then "--species '" + species        + "'" else ""} \
            ~{if defined(strain)           then "--strain '" + strain          + "'" else ""} \
            ~{if complete                  then "--complete"                        else ""} \
            ~{if ncbi_compliant            then "--compliant"                       else ""} \
            ~{if defined(locus_tag_prefix) then "--locus-tag '" + locus_tag_prefix + "'" else ""} \
            "~{contigs}"
    >>>

    output {
        File annotations_tsv = "~{file_prefix}.tsv"
        File gff3 = "~{file_prefix}.gff3"
        File gbff = "~{file_prefix}.gbff"
        File embl = "~{file_prefix}.embl"
        File fna = "~{file_prefix}.fna"
        File ffn = "~{file_prefix}.ffn"
        File faa = "~{file_prefix}.faa"
        File inference_metrics_tsv = "~{file_prefix}.inference.tsv"
        File hypotheticals_tsv = "~{file_prefix}.hypotheticals.tsv"
        File hypotheticals_faa = "~{file_prefix}.hypotheticals.faa"
        File summary_txt = "~{file_prefix}.txt"
        File png = "~{file_prefix}.png"
        File svg = "~{file_prefix}.svg"
        File summary_json = "~{file_prefix}.json"
    }

    #########################
    RuntimeAttr default_attr = object {
        cpu_cores:          16,
        mem_gb:             64,
        disk_gb:            disk_size,
        boot_disk_gb:       25,
        preemptible_tries:  0,
        max_retries:        0,
        docker:             "mjfos2r/bakta:latest"
    }
    RuntimeAttr runtime_attr = select_first([runtime_attr_override, default_attr])
    runtime {
        cpu:                    select_first([runtime_attr.cpu_cores,         default_attr.cpu_cores])
        memory:                 select_first([runtime_attr.mem_gb,            default_attr.mem_gb]) + " GiB"
        disks: "local-disk " +  select_first([runtime_attr.disk_gb,           default_attr.disk_gb]) + " HDD"
        bootDiskSizeGb:         select_first([runtime_attr.boot_disk_gb,      default_attr.boot_disk_gb])
        preemptible:            select_first([runtime_attr.preemptible_tries, default_attr.preemptible_tries])
        maxRetries:             select_first([runtime_attr.max_retries,       default_attr.max_retries])
        docker:                 select_first([runtime_attr.docker,            default_attr.docker])
    }
}