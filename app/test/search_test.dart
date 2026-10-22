import 'package:flutter_test/flutter_test.dart';
import 'package:qorybook/models/book.dart';
import 'package:qorybook/services/search.dart';

Book _book(String id, String title, {String authors = '', List<String> themes = const [], int views = 0}) =>
    Book.fromJson({
      'id': id,
      'source': 'budi',
      'title': title,
      'authors': authors,
      'levels': ['paud'],
      'kind': 'buku',
      'format': 'pdf',
      'themes': themes,
      'media': 'https://example.com/$id.pdf',
      'views': views,
    });

void main() {
  final books = [
    _book('1', 'Kelinci dan Kura-Kura', authors: 'Sari Dewi', themes: ['Hewan dan Tumbuhan'], views: 10),
    _book('2', 'Celengan Ruru', authors: 'Supriyatin', themes: ['Anak Indonesia'], views: 50),
    _book('3', 'Si Kancil Mencuri Timun', themes: ['Cerita Rakyat'], views: 5),
    _book('4', 'Kue Lapis Harimau', themes: ['Kuliner'], views: 99),
  ];
  final search = BookSearch(books);

  test('judul persis paling atas', () {
    expect(search.search('celengan ruru').first.id, '2');
  });

  test('awalan kata judul', () {
    expect(search.search('kanc').map((b) => b.id), ['3']);
  });

  test('cari berdasarkan penulis', () {
    expect(search.search('supriyatin').map((b) => b.id), ['2']);
  });

  test('cari berdasarkan tema', () {
    expect(search.search('kuliner').map((b) => b.id), ['4']);
  });

  test('toleran salah ketik', () {
    expect(search.search('kelnci').map((b) => b.id), contains('1'));
    expect(search.search('harimu').map((b) => b.id), contains('4'));
  });

  test('semua kata harus cocok', () {
    expect(search.search('kancil kuliner'), isEmpty);
  });

  test('kosong untuk kueri kosong', () {
    expect(search.search('   '), isEmpty);
  });

  test('normalisasi aksen dan tanda baca', () {
    expect(BookSearch.normalize('Kura-Kura, Café!'), 'kura kura cafe');
  });
}
