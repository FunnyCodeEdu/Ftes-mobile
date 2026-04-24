import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:ftes/core/error/failures.dart';
import 'package:ftes/core/usecases/usecase.dart';
import '../repositories/auth_repository.dart';

class ActivateUserUseCase implements UseCase<void, ActivateUserParams> {
  final AuthRepository repository;

  ActivateUserUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(ActivateUserParams params) async {
    return await repository.activateUser(params.accessToken);
  }
}

class ActivateUserParams extends Equatable {
  final String accessToken;

  const ActivateUserParams({required this.accessToken});

  @override
  List<Object> get props => [accessToken];
}
