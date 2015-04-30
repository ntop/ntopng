
/**
 * This is just a more "practical" example that illustrates how
 * to index a table using a bitmap. It is based of a piece of
 * code by Kelly Sommers.
 */

#include <vector>
#include <iostream>
#include <map>
#include <string>
#include <ewah.h>
#include <string>
#include <algorithm>

using namespace std;

vector<string> fromarraytovector(string * x, const size_t n) {
	vector < string > ans;
	for (size_t i = 0; i < n; ++i) {
		ans.push_back(x[i]);
	}
	return ans;
}

vector<vector<string> > ReadFile() {
	vector < vector<string> > ans;
	string row1[9] = { "Afghanistan", "2011", "TOTAL", "ALL COMMODITIES",
			"Import", "6390310947", "", "No Quantity", "" };
	string row2[9] = { "Afghanistan", "2011", "TOTAL", "ALL COMMODITIES",
			"Export", "375850935", "", "No Quantity", "" };
	string row3[9] = { "Afghanistan", "2010", "TOTAL", "ALL COMMODITIES",
			"Import", "5154249867", "", "No Quantity", "" };
	string row4[9] = { "Afghanistan", "2010", "TOTAL", "ALL COMMODITIES",
			"Export", "388483635", "", "No Quantity", "" };
	string row5[9] = { "Afghanistan", "2009", "TOTAL", "ALL COMMODITIES",
			"Import", "3336434781", "", "No Quantity", "" };
	string row6[9] = { "Afghanistan", "2009", "TOTAL", "ALL COMMODITIES",
			"Export", "403441006", "", "No Quantity", "" };
	string row7[9] = { "Afghanistan", "2008", "TOTAL", "ALL COMMODITIES",
			"Import", "3019860129", "", "No Quantity", "" };
	string row8[9] = { "Afghanistan", "2008", "TOTAL", "ALL COMMODITIES",
			"Export", "540065594", "", "No Quantity", "" };
	string row9[9] = { "Albania", "2011", "TOTAL", "ALL COMMODITIES", "Import",
			"5395853069", "", "No Quantity", "" };
	string row10[9] = { "Albania", "2011", "TOTAL", "ALL COMMODITIES",
			"Export", "1948207305", "", "No Quantity", "" };
	string row11[9] = { "Albania", "2010", "TOTAL", "ALL COMMODITIES",
			"Import", "4602774967", "", "No Quantity", "" };
	string row12[9] = { "Albania", "2010", "TOTAL", "ALL COMMODITIES",
			"Export", "1549955724", "", "No Quantity", "" };
	string row13[9] = { "Albania", "2010", "TOTAL", "ALL COMMODITIES",
			"Re-Import", "26393", "", "No Quantity", "" };
	string row14[9] = { "Albania", "2009", "TOTAL", "ALL COMMODITIES",
			"Import", "4548287875", "", "No Quantity", "" };
	string row15[9] = { "Albania", "2009", "TOTAL", "ALL COMMODITIES",
			"Export", "1087914902", "", "No Quantity", "" };
	string row16[9] = { "Albania", "2009", "TOTAL", "ALL COMMODITIES",
			"Re-Import", "272403", "", "No Quantity", "" };
	string row17[9] = { "Albania", "2008", "TOTAL", "ALL COMMODITIES",
			"Import", "5250490022", "", "No Quantity", "" };
	string row18[9] = { "Albania", "2008", "TOTAL", "ALL COMMODITIES",
			"Export", "1354921653", "", "No Quantity", "" };
	string row19[9] = { "Albania", "2008", "TOTAL", "ALL COMMODITIES",
			"Re-Export", "810868093", "", "No Quantity", "" };
	string row20[9] = { "Albania", "2008", "TOTAL", "ALL COMMODITIES",
			"Re-Import", "509068", "", "No Quantity", "" };
	string row21[9] = { "Albania", "2007", "TOTAL", "ALL COMMODITIES",
			"Import", "4200864046", "", "No Quantity", "" };
	string row22[9] = { "Albania", "2007", "TOTAL", "ALL COMMODITIES",
			"Export", "1077690359", "", "No Quantity", "" };
	string row23[9] = { "Albania", "2007", "TOTAL", "ALL COMMODITIES",
			"Re-Import", "4494753", "", "No Quantity", "" };
	ans.push_back(fromarraytovector(&row1[0], 9));
	ans.push_back(fromarraytovector(&row2[0], 9));
	ans.push_back(fromarraytovector(&row3[0], 9));
	ans.push_back(fromarraytovector(&row4[0], 9));
	ans.push_back(fromarraytovector(&row5[0], 9));
	ans.push_back(fromarraytovector(&row6[0], 9));
	ans.push_back(fromarraytovector(&row7[0], 9));
	ans.push_back(fromarraytovector(&row8[0], 9));
	ans.push_back(fromarraytovector(&row9[0], 9));
	ans.push_back(fromarraytovector(&row10[0], 9));
	ans.push_back(fromarraytovector(&row11[0], 9));
	ans.push_back(fromarraytovector(&row12[0], 9));
	ans.push_back(fromarraytovector(&row13[0], 9));
	ans.push_back(fromarraytovector(&row14[0], 9));
	ans.push_back(fromarraytovector(&row15[0], 9));
	ans.push_back(fromarraytovector(&row16[0], 9));
	ans.push_back(fromarraytovector(&row17[0], 9));
	ans.push_back(fromarraytovector(&row18[0], 9));
	ans.push_back(fromarraytovector(&row19[0], 9));
	ans.push_back(fromarraytovector(&row20[0], 9));
	ans.push_back(fromarraytovector(&row21[0], 9));
	ans.push_back(fromarraytovector(&row22[0], 9));
	ans.push_back(fromarraytovector(&row23[0], 9));

	return ans;
}

map<string, EWAHBoolArray<uint32_t> > indexColumn(vector<vector<string> > rows,
		size_t whichcolumn) {
	map<string, EWAHBoolArray<uint32_t> > indexes;
	for (size_t i = 0; i < rows.size(); i++) {
		indexes[rows[i][whichcolumn]].set(i);
	}
	return indexes;
}

int main() {
	vector < vector<string> > rows = ReadFile();
	cout << "We index the second column of our fictitious table." << endl;

	map<string, EWAHBoolArray<uint32_t> > index = indexColumn(rows, 1);

	size_t rowCount = 0;
	size_t actualRowCount = 0;
	size_t diskByteCount = 0;
	size_t compressedByteCount = 0;
	for (map<string, EWAHBoolArray<uint32_t> >::iterator i = index.begin(); i
			!= index.end(); ++i) {
		const string & term = i->first;
		EWAHBoolArray<uint32_t> & bitmap = i->second;

		cout << " the term '" << term << "' appears " << bitmap.numberOfOnes()
				<< " times" << endl;

		for (EWAHBoolArray<uint32_t>::const_iterator j = bitmap.begin(); j
				!= bitmap.end(); ++j) {
			cout << "term '" << term << "' appears at row index " << *j << endl;
			++actualRowCount;
		}

		rowCount += bitmap.numberOfOnes();
		diskByteCount += bitmap.sizeOnDisk();
		compressedByteCount += bitmap.computeStatistics().getCompressedSize();

	}

	cout << "TOTAL ROWS: " << rows.size() << endl;
	cout << "ACTUAL ROWS: " << actualRowCount << endl;
	cout << "INDEXED ROWS: " << rowCount << endl;
	cout << "TERMS: " << index.size() << endl;
	cout << "DISK BYTES: " << diskByteCount << endl;
	cout << "COMPRESSED BYTES: " << compressedByteCount << endl;


	return 0;
}

/**
 * Expected output:
 *
 * $ g++ -Wall  -o example2 example2.cpp -Iheaders
   $ ./example2
We index the second column of our fictitious table.
 the term '2007' appears 3 times
term '2007' appears at row index 20
term '2007' appears at row index 21
term '2007' appears at row index 22
 the term '2008' appears 6 times
term '2008' appears at row index 6
term '2008' appears at row index 7
term '2008' appears at row index 16
term '2008' appears at row index 17
term '2008' appears at row index 18
term '2008' appears at row index 19
 the term '2009' appears 5 times
term '2009' appears at row index 4
term '2009' appears at row index 5
term '2009' appears at row index 13
term '2009' appears at row index 14
term '2009' appears at row index 15
 the term '2010' appears 5 times
term '2010' appears at row index 2
term '2010' appears at row index 3
term '2010' appears at row index 10
term '2010' appears at row index 11
term '2010' appears at row index 12
 the term '2011' appears 4 times
term '2011' appears at row index 0
term '2011' appears at row index 1
term '2011' appears at row index 8
term '2011' appears at row index 9
TOTAL ROWS: 23
ACTUAL ROWS: 23
INDEXED ROWS: 23
TERMS: 5
DISK BYTES: 120
COMPRESSED BYTES: 10
*/
