
		if(REState!=(REPortBuffer&0b00000011)){
			if(REPortBuffer&0b00000010){				//if RE B high
				if(REPortBuffer&0b00000001){				//if RE A high								(3)
					if(REState==0b00000001)						//if last state RE A high + B low (4)
						REState = 0b00000011;
					else if(REState==0b00000010)				//if last state RE A low + B high (2)
						REState = 0b00000011;
					else
						REState = 0b00000100;
				}else{										//if RE A low								(2)
					if(REState==0b00000000){					//if last state RE A + B low (1)
						REState = 0b00000010;
						if(REDirection==0b00000000)
							REDirection = 0b00000010;
					}else if(REState==0b00000011)				//if last state RE A + B high (3)
						REState = 0b00000010;
					else
						REState = 0b00000100;
				}
			}else{									//if RE B low
				if(REPortBuffer&0b00000001){				//if RE A high								(4)
					if(REState==0b00000000){					//if last state RE A + B low (1)
						REState = 0b00000001;
						if(REDirection==0b00000000)
							REDirection = 0b00000001;
					}else if(REState==0b00000011)				//if last state RE A + B high (3)
						REState = 0b00000001;
					else
						REState = 0b00000100;
				}else{										//if RE A low								(1)
					if(REState==0b00000001){					//if last state RE A high + B low (4)
						if(REDirection==0b00000010)
							++REValue;
					}else if(REState==0b00000010){				//if last state RE A low + B high (2)
						if(REDirection==0b00000001)
							--REValue;
					}
					REState = 0b00000000;				//reset RE state
					REDirection = 0b00000000;			//reset RE direction
				}
			}
