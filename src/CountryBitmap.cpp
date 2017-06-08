/*
 *
 * (C) 2013-17 - ntop.org
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#include "ntop_includes.h"

/* *************************************** */

CountryBitmap::CountryBitmap(void) {
	bitmap = new uint64_t[4];
	activeCountry = 0;
}

/* *************************************** */

CountryBitmap::~CountryBitmap(void) {
	delete(bitmap);
}

/* *************************************** */

const char ** CountryBitmap::getActiveCountry() {
	uint8_t p = 0;
	const char ** list = new const char*[activeCountry];

	for (uint8_t i = 0; i < 256; i++)
		if (isActiveCountry(i)) {
			list[p] = getCountry(i);
			p++;
		}

	return list;
}

/* *************************************** */

uint8_t CountryBitmap::numActiveCountry() {
	return activeCountry;
}

/* *************************************** */

void CountryBitmap::setActiveCountry(uint8_t countryID) {
	if (!isActiveCountry(countryID)) {
		bitmap[countryID / 64] |= 1 << (countryID & 0x3F);
		activeCountry++;
	}
}

/* *************************************** */

bool CountryBitmap::isActiveCountry(uint8_t countryID) {
	return (bitmap[countryID / 64] >> (countryID & 0x3F)) & 1;
}

/* *************************************** */

const char * CountryBitmap::getCountry(uint8_t countryID) {
	switch (countryID) {
		case (0): return "--";
		case (1): return "AP";
		case (2): return "EU";
		case (3): return "AD";
		case (4): return "AE";
		case (5): return "AF";
		case (6): return "AG";
		case (7): return "AI";
		case (8): return "AL";
		case (9): return "AM";
		case (10): return "CW";
		case (11): return "AO";
		case (12): return "AQ";
		case (13): return "AR";
		case (14): return "AS";
		case (15): return "AT";
		case (16): return "AU";
		case (17): return "AW";
		case (18): return "AZ";
		case (19): return "BA";
		case (20): return "BB";
		case (21): return "BD";
		case (22): return "BE";
		case (23): return "BF";
		case (24): return "BG";
		case (25): return "BH";
		case (26): return "BI";
		case (27): return "BJ";
		case (28): return "BM";
		case (29): return "BN";
		case (30): return "BO";
		case (31): return "BR";
		case (32): return "BS";
		case (33): return "BT";
		case (34): return "BV";
		case (35): return "BW";
		case (36): return "BY";
		case (37): return "BZ";
		case (38): return "CA";
		case (39): return "CC";
		case (40): return "CD";
		case (41): return "CF";
		case (42): return "CG";
		case (43): return "CH";
		case (44): return "CI";
		case (45): return "CK";
		case (46): return "CL";
		case (47): return "CM";
		case (48): return "CN";
		case (49): return "CO";
		case (50): return "CR";
		case (51): return "CU";
		case (52): return "CV";
		case (53): return "CX";
		case (54): return "CY";
		case (55): return "CZ";
		case (56): return "DE";
		case (57): return "DJ";
		case (58): return "DK";
		case (59): return "DM";
		case (60): return "DO";
		case (61): return "DZ";
		case (62): return "EC";
		case (63): return "EE";
		case (64): return "EG";
		case (65): return "EH";
		case (66): return "ER";
		case (67): return "ES";
		case (68): return "ET";
		case (69): return "FI";
		case (70): return "FJ";
		case (71): return "FK";
		case (72): return "FM";
		case (73): return "FO";
		case (74): return "FR";
		case (75): return "SX";
		case (76): return "GA";
		case (77): return "GB";
		case (78): return "GD";
		case (79): return "GE";
		case (80): return "GF";
		case (81): return "GH";
		case (82): return "GI";
		case (83): return "GL";
		case (84): return "GM";
		case (85): return "GN";
		case (86): return "GP";
		case (87): return "GQ";
		case (88): return "GR";
		case (89): return "GS";
		case (90): return "GT";
		case (91): return "GU";
		case (92): return "GW";
		case (93): return "GY";
		case (94): return "HK";
		case (95): return "HM";
		case (96): return "HN";
		case (97): return "HR";
		case (98): return "HT";
		case (99): return "HU";
		case (100): return "ID";
		case (101): return "IE";
		case (102): return "IL";
		case (103): return "IN";
		case (104): return "IO";
		case (105): return "IQ";
		case (106): return "IR";
		case (107): return "IS";
		case (108): return "IT";
		case (109): return "JM";
		case (110): return "JO";
		case (111): return "JP";
		case (112): return "KE";
		case (113): return "KG";
		case (114): return "KH";
		case (115): return "KI";
		case (116): return "KM";
		case (117): return "KN";
		case (118): return "KP";
		case (119): return "KR";
		case (120): return "KW";
		case (121): return "KY";
		case (122): return "KZ";
		case (123): return "LA";
		case (124): return "LB";
		case (125): return "LC";
		case (126): return "LI";
		case (127): return "LK";
		case (128): return "LR";
		case (129): return "LS";
		case (130): return "LT";
		case (131): return "LU";
		case (132): return "LV";
		case (133): return "LY";
		case (134): return "MA";
		case (135): return "MC";
		case (136): return "MD";
		case (137): return "MG";
		case (138): return "MH";
		case (139): return "MK";
		case (140): return "ML";
		case (141): return "MM";
		case (142): return "MN";
		case (143): return "MO";
		case (144): return "MP";
		case (145): return "MQ";
		case (146): return "MR";
		case (147): return "MS";
		case (148): return "MT";
		case (149): return "MU";
		case (150): return "MV";
		case (151): return "MW";
		case (152): return "MX";
		case (153): return "MY";
		case (154): return "MZ";
		case (155): return "NA";
		case (156): return "NC";
		case (157): return "NE";
		case (158): return "NF";
		case (159): return "NG";
		case (160): return "NI";
		case (161): return "NL";
		case (162): return "NO";
		case (163): return "NP";
		case (164): return "NR";
		case (165): return "NU";
		case (166): return "NZ";
		case (167): return "OM";
		case (168): return "PA";
		case (169): return "PE";
		case (170): return "PF";
		case (171): return "PG";
		case (172): return "PH";
		case (173): return "PK";
		case (174): return "PL";
		case (175): return "PM";
		case (176): return "PN";
		case (177): return "PR";
		case (178): return "PS";
		case (179): return "PT";
		case (180): return "PW";
		case (181): return "PY";
		case (182): return "QA";
		case (183): return "RE";
		case (184): return "RO";
		case (185): return "RU";
		case (186): return "RW";
		case (187): return "SA";
		case (188): return "SB";
		case (189): return "SC";
		case (190): return "SD";
		case (191): return "SE";
		case (192): return "SG";
		case (193): return "SH";
		case (194): return "SI";
		case (195): return "SJ";
		case (196): return "SK";
		case (197): return "SL";
		case (198): return "SM";
		case (199): return "SN";
		case (200): return "SO";
		case (201): return "SR";
		case (202): return "ST";
		case (203): return "SV";
		case (204): return "SY";
		case (205): return "SZ";
		case (206): return "TC";
		case (207): return "TD";
		case (208): return "TF";
		case (209): return "TG";
		case (210): return "TH";
		case (211): return "TJ";
		case (212): return "TK";
		case (213): return "TM";
		case (214): return "TN";
		case (215): return "TO";
		case (216): return "TL";
		case (217): return "TR";
		case (218): return "TT";
		case (219): return "TV";
		case (220): return "TW";
		case (221): return "TZ";
		case (222): return "UA";
		case (223): return "UG";
		case (224): return "UM";
		case (225): return "US";
		case (226): return "UY";
		case (227): return "UZ";
		case (228): return "VA";
		case (229): return "VC";
		case (230): return "VE";
		case (231): return "VG";
		case (232): return "VI";
		case (233): return "VN";
		case (234): return "VU";
		case (235): return "WF";
		case (236): return "WS";
		case (237): return "YE";
		case (238): return "YT";
		case (239): return "RS";
		case (240): return "ZA";
		case (241): return "ZM";
		case (242): return "ME";
		case (243): return "ZW";
		case (244): return "A1";
		case (245): return "A2";
		case (246): return "O1";
		case (247): return "AX";
		case (248): return "GG";
		case (249): return "IM";
		case (250): return "JE";
		case (251): return "BL";
		case (252): return "MF";
		case (253): return "BQ";
		case (254): return "SS";
		case (255): return "01";
	}
}
