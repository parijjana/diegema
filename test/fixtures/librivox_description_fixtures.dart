/// Real LibriVox / archive.org book descriptions, captured 2026-09-24, run
/// through the same normalisation `TextSanitizer.sanitize` applies before a
/// description reaches `LibriVoxBook.description` (HTML tags stripped,
/// `<br>` -> newline, entities decoded, whitespace collapsed).
///
/// Sources:
/// - `(a)` archive.org advancedsearch `description` field
///   (`collection:librivoxaudio`), which already arrives as plain text.
/// - `(b)` librivox.org API feed `description` field
///   (`/api/feed/audiobooks/?format=json&extended=1`), which arrives as
///   HTML and was hand-sanitised here to match what the app actually sees.
///
/// Kept deliberately messy — inconsistent punctuation, missing periods,
/// absent fields — because that is what the real feeds produce.
library;

const Map<String, String> libriVoxDescriptionFixtures = {
  // (a) Normal novel. No period after the reader's name before the summary
  // starts ("...by NoelBadrian "One of..."), and the summary credit has no
  // parentheses ("- Summary by Noel Badrian").
  'castleRackrent': '''
LibriVox recording of Castle Rackrent by Maria Edgeworth. Read in English by NoelBadrian "One of the most inspired chronicles written in English" was the verdict of William Butler Yeats on the novel Castle Rackrent by Maria Edgeworth which was first published in 1800. It is recognised as the first true historical novel in English as well as the first Big-House novel. Written at the time when there was much debate about the Act of Union which proposed to unite Great Britain with Ireland, the book satirised the mismanagement of their Irish estates by Anglo-Irish landlords. Maria Edgeworth's writing is wonderful - informative, entertaining and amusing by turns. Just before publication, extensive footnotes, a glossary and a preface were added, to counteract any negative impact that the Edgeworth family feared it might have on The Act of Union. This 1895 Edition includes a wonderful Introduction by Anne Thackeray Ritchie. The novel is set in early 1780's Ireland and is narrated by Honest Thady, loyal steward to generations of the Rackrent family. These are: The generous Sir Patrick, the tight fisted Sir Murtagh (married into the Skinflint family), the cruel Sir Kit who locked his wealthy wife up in her room for seven years and the amiable spendthrift Sir Condy, who has no head for business and a fondness for whisky punch. Together, they have run the estate into debt and disaster. Jason Quirk, Thady's astute son sorts everything out in the end to his satisfaction but much to Thady's dismay. - Summary by Noel Badrian For further information, including links to online text, reader information, RSS feeds, CD cover or other formats (if available), please go to the LibriVox catalog page for this recording. For more free audio books or to become a volunteer reader, visit LibriVox.org . M4B Audiobook (141MB)
''',

  // (a) Normal novel, "clean" case: period after the reader's name,
  // parenthesised summary credit, mixed-case format line.
  'typeWriterGirl': '''
LibriVox recording of The Type-Writer Girl, by Grant Allen (under the pseudonym Olive Pratt Rayner). Read by Grant Hurlock. "There is no more pathetic figure in our world to-day than the common figure of the poor young lady, crushed between classes above and below, and left with scarce a chance of earning her bread with decency." So says Juliet Appleton's boss, encouraging her to put her story into print. How will this college-educated 23-year-old survive the Darwinian Battle of Life in late Victorian England? She's fundless in London but armed, by way of adaptive structures, with those two high-tech devices of the day: a bicycle for mobility and a typewriter for utility. (Summary by Grant Hurlock) For further information, including links to online text, reader information, RSS feeds, CD cover or other formats (if available), please go to the LibriVox catalog page for this recording. For more free audio books or to become a volunteer reader, visit LibriVox.org . M4B audio book (155mb)
''',

  // (a) Multilingual anthology with an explicit numbered contents list (20
  // items) and "Read in Multilingual by ...".
  'multilingualShortWorks035': '''
LibriVox recording of Multilingual Short Works Collection 035 - Poetry & Prose by Various. Read in Multilingual by Ehsan Ahmed Mehedi; lorda; laurakgibbs; Sonia; Piotr Nater; Hanna Ponomarenko; Claudia Caldi; and Joseph Finkberg This is our 35th collection of short pieces, poetry or prose, fiction and non-fiction, in several different languages (except standard English) as listed below. All chosen and recorded by Librivox volunteers. - Summary by ToddHW 1. French - Voyelles - 1:32 Arthur Rimbaud Link to text Keywords: voyelles, poésie, french poetry, rimbaud 2. German - Am Thurme - 2:04 Annette von Droste-Hülshoff Link to text Keywords: poem 3. Latin - De Abbate, Cibo, et Monachis - 2:08 Odo of Cheriton Link to text Keywords: Middle Ages, Medieval, Latin, fables, Aesop 4. Latin - De Ciconia et Catto - 1:51 Odo of Cheriton Link to text Keywords: Middle Ages, Medieval, Latin, fables, Aesop, animals 5. Latin - De Claustrali - 1:32 Odo of Cheriton Link to text Keywords: Middle Ages, Medieval, Latin, fables, Aesop 6. Luxembourgish - D'Margrétchen - 2:41 Michel Lentz Link to text Keywords: flowers, spring, love, nature, song 7. Polish - Na zdrowie - 1:00 Jan Kochanowski Link to text Keywords: zdrowie, pochwała, fraszka 8. Polish - O powieści historycznej - 44:50 Henryk Sienkiewicz Link to text Keywords: odczyt, powieść, argumenty, krytyka 9. Polish - O wojnie naszej, którą wiedziemy z szatanem, światem i ciałem - 1:13 Mikołaj Sęp Szarzyński Link to text Keywords: walka, Bóg, religia, życie, sonet 10. Polish - Walka byków - 45:34 Henryk Sienkiewicz Link to text Keywords: corrida, walka, Hiszpania, okrucieństwo 11. Russian - Однообразные мелькают [Odnoobraznye mel'kaiut] - 1:20 Николай Гумилёв Link to text Keywords: любовь, смерть, мечта 12. Spanish - Caá-mí - 27:04 Domingo Parodi Link to text Keywords: yerba mate, caá-mí, guaraní, té, café, yerbas medicinales, conocimientos indígenas 13. Spanish - Carta de une hormiga esclavista - 8:56 Santiago Ramón y Cajal Link to text key words: hormigas, humanidad, estructura social 14. Spanish - El cubismo - 18:22 Enrique Gómez Carrillo Link to text Keywords: Cubismo, Picasso, crítica de arte 15. Spanish - Filipinas dentro de cien años - 1:14:26 José Rizal Link to text Keywords: Colonialismo, Racismo, Frailismo 16. Spanish - Introducción al Manual de histología normal - 24:44 Santiago Ramón y Cajal Link to text key words: historia de la teoría celular 17. Spanish - Observaciones preliminares - 18:52 Domingo Parodi Link to text Keywords: guaraní, yerbas medicinales, indios 18. Spanish - La psicología del viaje - 51:33 Enrique Gómez Carrillo Link to text Keywords: literatura de viajes; turismo; países 19. Yiddish - Varzweiflung - 3:39 Morris Rosenfeld Link to text Keywords: despair, death, hard work, memento mori 20. Yiddish - Wuhin - 1:30 Morris Rosenfeld Link to text Keywords: poverty, work, hard life For further information, including links to online text, reader information, RSS feeds, CD cover or other formats (if available), please go to the LibriVox catalog page for this recording. For more free audio books or to become a volunteer reader, visit librivox.org . M4B Audiobook (132MB)
''',

  // (a) Short collection with a semicolon "includes:" list embedded in one
  // sentence, rather than a numbered list.
  'firstChapterCollection002': '''
LibriVox recording of First Chapter Collection 002. Read by Librivox Volunteers. Librivox First Chapter Collection 002 - a collection of the first chapters of 15 different books, chosen by Librivox volunteers. This volume includes the first chapters of: Tolstoy's Anna Karenina (in the original Russian); children's classics Oliver Twist, Treasure Island and The Secret Garden; F. Scott Fitzgerald's This Side of Paradise; the Book of Mormon; and more! (Summary by Rachel) For further information, including links to online text, reader information, RSS feeds, CD cover or other formats (if available), please go to the LibriVox catalog page for this recording. For more free audio books or to become a volunteer reader, visit LibriVox.org . Download M4B (95MB)
''',

  // (a) Poetry, weekly-poetry-project style, long semicolon-separated list
  // of volunteer readers ending in "and X".
  'toTheClouds': '''
LibriVox  volunteers bring you 15 recordings of To The Clouds by John Clare. This was the Weekly Poetry project for February 11, 2024. Read in English by Alan Mapstone; Bruce Kachuk; Beeswaxcandle; Cassandra A.M.; Chris Pyle; dc; Newgatenovelist; Inkell; Lee Ann Howlett; Larry Wilson; MikeMilbrath; Melissa T.; Patrick Randall; redrun and Stacey Malcolm. His biographer Jonathan Bate called Clare "the greatest labouring-class poet that England has ever produced. No one has ever written more powerfully of nature, of a rural childhood, and of the alienated and unstable self."(Summary by Wikipedia) For further information, including links to online text, reader information, RSS feeds, CD cover or other formats (if available), please go to the LibriVox catalog page for this recording. For more free audio books or to become a volunteer reader, visit librivox.org . M4B Audiobook (11MB)
''',

  // (a) Multi-reader "LibriVox Volunteers" collection, very short summary.
  'shortPoetryCollection277': '''
LibriVox recording of Short Poetry Collection 277 by Various. Read in English by LibriVox Volunteers. This is a collection of 40 poems read in English by LibriVox volunteers during June 2026. For further information, including links to online text, reader information, RSS feeds, CD cover or other formats (if available), please go to the LibriVox catalog page for this recording. For more free audio books or to become a volunteer reader, visit librivox.org . M4B Audiobook (60MB)
''',

  // (a) No "LibriVox recording of X by Y. Read in <lang> by ..." opener at
  // all (single-chapter serial excerpt) and a summary credit with neither
  // parentheses nor a leading dash.
  'historyOfEngland05': '''
This chapter of Macaulay's, History of England is concerned, for a large part, with insurrection against James II and his manoeuverings to suppress these.Argyle has been sheltering in Holland and returns to raise an army against James. Although brave and quick witted, he was no leader of men and the army became a confused rabble and were dispersed. Argyle was captured and died bravely. Monmouth had also been sheltering in Holland and he landed at Lyme and declared himself king on 20th June 1685. He was defeated at the battle of Sedgemoor and eventually caught and executed. Monmouth is a fine romantic and of course ultimately tragic figure. The chapter comes to an end with the Bloody Assizes and the very bloody Judge Jeffries. Summary by Jim Mowatt For further information, including links to online text, reader information, RSS feeds, CD cover or other formats (if available), please go to the LibriVox catalog page for this recording. Download M4B (132MB)
''',

  // (a) Single narrator followed by a stray semicolon instead of a period
  // before the summary starts.
  'canYouForgiveHer': '''
LibriVox recording of Can You Forgive Her?  by Anthony Trollope. Read in English by Deon Gines; Can You Forgive Her was published over 2 years in serial form. It follows the life story of three women involved with courtship and marriage decisions. - Summary by Deon Gines For further information, including links to online text, reader information, RSS feeds, CD cover or other formats (if available), please go to the LibriVox catalog page for this recording. For more free audio books or to become a volunteer reader, visit librivox.org . M4B Audiobook 01-20 (259MB) M4B Audiobook 21-40 (256MB) M4B Audiobook 41-60 (256MB) M4B Audiobook 61-80 (249MB)
''',

  // (a) Non-English (Spanish), no period after the reader's name, and a
  // "contiene:" list of period-separated fragments rather than a clean
  // numbered/semicolon list.
  'historiaDeHerodoto3': '''
LibriVox recording of Libro III de la Historia de Heródoto by Heródoto. (Translated by S. J. P. Bartolomé Pou.) Read in Spanish by Tux Las Historias de Heródoto de Halicarnaso (484–después del 430 a. C.) es una obra que tiene como objetivo narrar las Guerras Médicas. Se trata de la primera obra historiográfica griega que nos ha llegado íntegra y está dividida en nueve libros, cada uno de ellos dedicado a una musa. El Libro III contine: Causas que indujeron a Cambises a atacar Egipto. Campaña militar. Detalles acerca del carácter soberbio e impío de Cambises. Muerte de Cambises y entronización de Darío I. Las Historias de Heródoto constituyen, dentro de la prosa griega, el mejor ejemplo de composición literaria abierta; es decir, no opera de modo rectilíneo, sino que intercala todo tipo de retardaciones y digresiones en el argumento central. Este rasgo lo comparte con la Ilíada. - Summary by Wikipedia For further information, including links to online text, reader information, RSS feeds, CD cover or other formats (if available), please go to the LibriVox catalog page for this recording. For more free audio books or to become a volunteer reader, visit LibriVox.org . M4B Audiobook (107MB)
''',

  // (a) Non-English (Dutch), no "LibriVox recording of ... Read in English
  // by ..." pattern at all (the whole opener is in Dutch), bilingual body.
  'zesNovellenEmants': '''
Librivox luisterboek van zes novellen van Marcellus Emants, gelezen door Julie VW, Marcel Coenders, Bart de Leeuw en Anna Simon. Novellen van Marcellus Emants: Een avontuur, Najaarsstormen en Fanny verschenen samen in een boek uit 1879, nadat de eerste twee al eerder waren afgedrukt in een literair tijdschrift. Het laatste verhaal was ook bedoeld voor een tijdschrift, maar werd daaruit teruggetrokken, omdat de redacteuren bang waren dat het te erotisch was. De inleiding bij dit luisterboek hoort bij deze eerste drie novellen. Dood, Ontwaakt en Op zee verschenen in De Gids in 1890, 1896 en 1897. Deze drie zijn later ook in diverse boekuitgaven uitgekomen. Short English description: Six short story's, all but one published in literary magazines in the Netherlands. Voor meer gratis audioboeken (in meer dan 25 talen), of om zelf vrijwilliger te worden, ga naar LibriVox.org . For more free audio books (in more than 25 languages) or to become a volunteer reader, visit LibriVox.org . For further information, including links to online text, reader information, RSS feeds, CD cover or other formats (if available), please go to the LibriVox catalog page for this recording. M4B luisterboek (233MB)
''',

  // (a) Very short: multiple narrators, dash summary credit, no parens.
  'howTheMastiffsWentToIceland': '''
LibriVox recording of How the "Mastiffs" Went to Iceland by Anthony Trollope. Read in English by jenno; Piotr Nater. Cynthia Malone; Mark F. Smith. Anthony Trollope recounts his travel with the other passengers of the ship, Mastiff, to Iceland. He describes their journey by ship as well as their experiences in Iceland. - Summary by Elsie Selwyn For further information, including links to online text, reader information, RSS feeds, CD cover or other formats (if available), please go to the LibriVox catalog page for this recording. For more free audio books or to become a volunteer reader, visit librivox.org . M4B Audiobook (50MB)
''',

  // (b) librivox.org API feed. No LibriVox boilerplate opener/tail at all
  // (the feed's description is just the summary), paragraph breaks already
  // collapsed from `<br><br>` by TextSanitizer, summary credit mid-text.
  'countOfMonteCristo': '''
The Count of Monte Cristo (French: Le Comte de Monte-Cristo) is an adventure novel by Alexandre Dumas, père. It is often considered, along with The Three Musketeers, as Dumas's most popular work. The writing of the work was completed in 1844. Like many of his novels, it is expanded from the plot outlines suggested by his collaborating ghostwriter Auguste Maquet.

The story takes place in France, Italy, islands in the Mediterranean and the Levant during the historical events of 1815–1838 (from just before the Hundred Days through the reign of Louis-Philippe of France). The historical setting is a fundamental element of the book. It is primarily concerned with themes of justice, vengeance, mercy, and forgiveness, and is told in the style of an adventure story. (Summary from Wikipedia)

This book contains alternate versions of a number of chapters – indicated by an alt after the file number. The Zip files contain both versions of these chapters.

There are 2 versions of the M4Bs made , one containing the original files for these chapters (4 parts), the other containing the alternate files for the chapters (5 parts).
''',

  // (b) librivox.org API feed. Narrators named only in free prose, no
  // "Read by"/"Read in English by" line to key off at all; ends abruptly
  // without a trailing period.
  'lettersOfTwoBrides': '''
Letters of Two Brides is an epistolary novel. The two brides are Louise de Chaulieu (Madame Gaston) and Renée de Maucombe (Madame l'Estorade). The women became friends during their education at a convent and upon leaving began a life-long correspondence. For a 17 year period, they exchange letters describing their lives.

Michelle Crandall reads Renee’s letters, and Kara Shallenberg reads Louise’s. Letters from the men in their lives are read by Peter Yearsley, David Barnes, Denny Sayers, and Sean McKinley
''',

  // Empty/whitespace-only input.
  'empty': '',
  'whitespaceOnly': '   \n\n  \t  ',
};
