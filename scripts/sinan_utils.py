from __future__ import annotations

import hashlib
from collections.abc import Mapping


CSV_COLUMNS = [
    "arquivo_origem",
    "ano_arquivo",
    "TP_NOT",
    "ID_AGRAVO",
    "CS_SUSPEIT",
    "DT_NOTIFIC",
    "SEM_NOT",
    "NU_ANO",
    "SG_UF_NOT",
    "ID_MUNICIP",
    "ID_REGIONA",
    "DT_SIN_PRI",
    "SEM_PRI",
    "NU_IDADE_N",
    "CS_SEXO",
    "CS_GESTANT",
    "CS_RACA",
    "CS_ESCOL_N",
    "SG_UF",
    "ID_MN_RESI",
    "ID_RG_RESI",
    "ID_PAIS",
    "NDUPLIC_N",
    "IN_VINCULA",
    "DT_INVEST",
    "ID_OCUPA_N",
    "CLASSI_FIN",
    "CRITERIO",
    "TPAUTOCTO",
    "COUFINF",
    "COPAISINF",
    "COMUNINF",
    "DOENCA_TRA",
    "EVOLUCAO",
    "DT_OBITO",
    "DT_ENCERRA",
    "CS_FLXRET",
    "FLXRECEBI",
    "TP_SISTEMA",
    "TPUNINOT",
    "ID_UNIDADE",
    "ANO_NASC",
    "DT_DIGITA",
]

RAW_COLUMNS = [
    "arquivo_origem",
    "ano_arquivo",
    "tp_not",
    "id_agravo",
    "cs_suspeit",
    "dt_notific",
    "sem_not",
    "nu_ano",
    "sg_uf_not",
    "id_municip",
    "id_regiona",
    "dt_sin_pri",
    "sem_pri",
    "nu_idade_n",
    "cs_sexo",
    "cs_gestant",
    "cs_raca",
    "cs_escol_n",
    "sg_uf",
    "id_mn_resi",
    "id_rg_resi",
    "id_pais",
    "nduplic_n",
    "in_vincula",
    "dt_invest",
    "id_ocupa_n",
    "classi_fin",
    "criterio",
    "tpautocto",
    "coufinf",
    "copaisinf",
    "comuninf",
    "doenca_tra",
    "evolucao",
    "dt_obito",
    "dt_encerra",
    "cs_flxret",
    "flxrecebi",
    "tp_sistema",
    "tpuninot",
    "id_unidade",
    "ano_nasc",
    "dt_digita",
]

CSV_TO_RAW_COLUMN = dict(zip(CSV_COLUMNS, RAW_COLUMNS))


def clean_raw_value(value: object) -> str:
    if value is None:
        return ""
    return str(value).strip()


def row_hash_from_values(values: list[str]) -> str:
    content = "\x1f".join(values)
    return hashlib.sha1(content.encode("utf-8")).hexdigest()


def row_hash_from_csv_row(row: Mapping[str, object]) -> str:
    values = [clean_raw_value(row.get(column)) for column in CSV_COLUMNS]
    return row_hash_from_values(values)


def decode_idade_sinan(value: object) -> int | None:
    clean_value = clean_raw_value(value)
    if len(clean_value) != 4 or not clean_value.isdigit():
        return None

    unit = int(clean_value[0])
    amount = int(clean_value[1:])

    if unit in (1, 2):
        return 0
    if unit == 3:
        return int(amount // 12)
    if unit == 4:
        return amount
    return None
