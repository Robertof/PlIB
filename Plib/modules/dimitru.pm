#!/usr/bin/perl
# Name: Dimitru (il rumeno) module
# Author: Robertof
# Language: ITALIAN

package Plib::modules::dimitru;
sub new {
	my $phrases = [
		"AVERE ROTO CAZU CON TUE SUONERIE DI MERDA! SE TI CHIAPO SPACO TELEFONINO E RUBO MUTURINO!",
		"PRENDO BAMBINA PICOLA E STRANGOLO CON PELICOLA!",
		"PRENDO MAZA UCIDO TUA RAGAZA!",
		"A NATALE SPACO BOTILIA SU BABO NATALE!",
		"A NATALE AMAZO TUOI, A PASQUA TUTTI VOI!",
		"Noi in Rumania amare gioco di botilia.. Giriamo botilia e chi capitare sua testa decapitare!",
		"PRENDO ACENDINI BRUSCIO GELMINI!",
		"STUPRO TUA FILIA E SCAPO IN SICILIA!",
		"SPACO FINESTRA INCULO MAESTRA!",
		"Porta in alto cultelo talio gola fratelo se poi spaco botilia talio gola anche a familia",
		"PRENDO CULTELO TALIO PISELO",
		"PRENDO FORCHETA TALIO TUE PALE",
		"PRENDO CORTELO E AMAZO GELMINI",
		"VEDO COPIATORE CI PASO SOPRA CON TRATORE!",
		"PRENDO PENARELO AMAZO BIDELO!",
		"SPACO BOTILIA BESTEMIO TUTA SACRA FAMILIA! PORCU DIU!",
		"MALEDETI TRUZI, VE INFILO IN CULO 346384 STRUZI!",
		"SPACO BOTILIA PRENDIAMO BASTILIA",
		"FRATELO D'ITALIA, L'ITALIA S'E' DESTA, SE FAI UN TORTO TI SPACO LA TESTA!",
		"PRENDO BANANA STUBRO PUTANA!",
		"PRENDO FUCILE AMAZO CIVILE!",
		"PRENDO UNA PALMA E STUPRO UNA SALMA",
		"TIRO UNA BOMBA E STUPRO COLOMBA",
		"ROMPO ASCENSORE E AMAZO DOTORE",
		"SPACO BICHIERE E UCIDO INFERMIERE",
		"TALIO GOLA A BASTARDO CAMERIERE",
		"SPACO VETRO DI NUTELA.. AMAZO A TUTI LA SORELA!",
		"PASO CON ROSO INVESTO A PIU' NON POSO!",
		"PASO CON GIALO INVESTO MARESCIALO!",
		"PRENDO STAMPELA UCIDO SORELA!",
		"PRENDO MARTELO UCIDO FRATELO!",
		"SINIORE, MI DIA BOTILIA DI VODKA! SINIORE: Vuole anche un bicchiere? OVIO, DA SPACARE I TESTA A TE E A TUTO I QUARTIERE!",
		"PRENDO BICHIERE AMAZO CARABINIERE!",
		"STRAPO DIARIO UCIDO SUPER MARIO!",
		"TU CARTA? IO STRAPO FOLIO!",
		"PRENDO TAVOLINO AMAZO CUGINO!",
		"VADO IN BICICLETA E SCIPO BORSA A VECHIETA!",
		"VADO IN PIAZA E STUPRO RAGAZA!",
		"♫ Ninna nanna ninna oh ♫ A chi oggi gola taliero'? ♫",
		"♫ Se sei felice e tu lo sai spaca botilia ♫ Se sei felice e tu lo sai amaza familia ♫",
		"UNA BOTILIA SPACATA AL GIORNO TOLIE ITALIANO DI TORNO!",
		"MI RADO BAFI E FACIO CULO A GHEDAFI!",
		"PRENDO BENZINA BRUSCIO BAMBINA!",
		"SINIORE, COMPRA MIA GIACA RUBATA, SE NON VUOLE CHE SUA GOLA SIA TALIATA!",
		"♫ Mi chiamo virgola, sono gatino.. ♫ Talio gola e rubo telefonino! ♫",
		"SPACO DAMIGIANA UCIDO HANA MONTANA!",
		"SPACO PERONI UCIDO BERLUSCONI!",
		"GELMINI TALIA FONDI PE SCUOLA? IO TALIO SUA GOLA, CAZU!",
		"DARE ME 5 € PER MIA FAMILIA O TALIO GOLA!"
	];
	my $__x = {"p"=>$phrases};
	bless $__x, $_[0];
	return $__x;
}
sub atInit { return 1; }
sub atWhile {
	my ($self, $isTest, $botClass, $sent, $nick, $ident, $host) = @_;
	return 1 if $isTest;
	my $info;
	if ($nick and $ident and $host and $info = $botClass->matchMsg ($sent, 1) and $info->{"message"} =~ /^!dimitru$/i) {
		$botClass->sendMsg ($info->{"chan"}, $self->{"p"}->[int (rand (scalar (@{$self->{"p"}})))]);
	}
}

1;
