package f;

type MyFunctionService struct{}

func (*MyFunctionService) Available() {
  
}

func (*MyFunctionService) Ready() {
  
}

func (*MyFunctionService) New() MyFunctionService { // breaks the process boundary
  return MyFunctionService{};
}

func (*MyFunctionService) Start() {

}



func (*MyFunctionService) Handle(http... request response){
  
}

